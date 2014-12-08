#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <monkit.h>
#include <semaphore.h>

#include <list>
#include <time.h>

#include "StdDmaIndication.h"
#include "DmaDebugRequestProxy.h"
#include "MMUConfigRequestProxy.h"
#include "FlashIndicationWrapper.h"
#include "FlashRequestProxy.h"

#define BLOCKS_PER_CHIP 2
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8

#define PAGE_SIZE 8192
#define NUM_TAGS 128

typedef enum {
	UNINIT,
	ERASED,
	WRITTEN
} FlashStatusT;

typedef struct {
	bool busy;
	int bus;
	int chip;
	int block;
} TagTableEntry;

FlashRequestProxy *device;

pthread_mutex_t flashReqMutex;
pthread_cond_t flashFreeTagCond;

//8k * 128
size_t dstAlloc_sz = PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
size_t srcAlloc_sz = PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
int dstAlloc;
int srcAlloc;
unsigned int ref_dstAlloc; 
unsigned int ref_srcAlloc; 
unsigned int* dstBuffer;
unsigned int* srcBuffer;
unsigned int* readBuffers[NUM_TAGS];
unsigned int* writeBuffers[NUM_TAGS];
TagTableEntry readTagTable[NUM_TAGS]; 
TagTableEntry writeTagTable[NUM_TAGS]; 
TagTableEntry eraseTagTable[NUM_TAGS]; 
FlashStatusT flashStatus[NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];

int testPass = 1;
bool verbose = true;
int curReadsInFlight = 0;
int curWritesInFlight = 0;
int curErasesInFlight = 0;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}


unsigned int hashAddrToData(int bus, int chip, int blk, int word) {
	return ((bus<<24) + (chip<<20) + (blk<<16) + word);
}


bool checkReadData(int tag) {
	TagTableEntry e = readTagTable[tag];
	int goldenData;
	if (flashStatus[e.bus][e.chip][e.block]==WRITTEN) {
		int numErrors = 0;
		for (int word=0; word<PAGE_SIZE/sizeof(unsigned int); word++) {
			goldenData = hashAddrToData(e.bus, e.chip, e.block, word);
			if (goldenData != readBuffers[tag][word]) {
				fprintf(stderr, "LOG: **ERROR: read data mismatch! Expected: %x, read: %x\n", goldenData, readBuffers[tag][word]);
				numErrors++; 
				testPass = 0;
			}
		}
		if (numErrors==0) {
			fprintf(stderr, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.bus][e.chip][e.block]==ERASED) {
		//only check first word. It may return 0 if bad block, or -1 if erased
		if (readBuffers[tag][0]==-1) {
			fprintf(stderr, "LOG: Read check pass on erased block!\n");
		}
		else if (readBuffers[tag][0]==0) {
			fprintf(stderr, "LOG: Warning: potential bad block, read erased data 0\n");
		}
		else {
			fprintf(stderr, "LOG: **ERROR: read data mismatch! Expected: ERASED, read: %x\n", readBuffers[tag][0]);
			testPass = 0;
		}
	}
	else {
		fprintf(stderr, "LOG: **ERROR: flash block state unknown. Did you erase before write?\n");
		testPass = 0;
	}
}

timespec starttime;

volatile int lock = 1;

class FlashIndication : public FlashIndicationWrapper
{

	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

  virtual void waitExceeded(unsigned int i){
    printf( "Response Wait Exceeded\n");
  }
  virtual void sendReq(unsigned int wh, unsigned int iDash, unsigned int row, unsigned int col){
    printf( "Req sent: %d %d %d %d\n", wh, iDash, row, col);
  }
  virtual void sendResp(unsigned int wh, unsigned int iDash){
    printf( "Resp received: %d %d\n", wh, iDash);
  }
  virtual void sendSize(unsigned int i, unsigned int j, unsigned int k){
    printf( "Send Size %u %u %u\n", i, j, k);
  }
  virtual void recvSize(unsigned int i, unsigned int j, unsigned int k){
    printf( "Recv Size %u %u %u\n", i, j, k);
  }
  virtual void finish(unsigned int errCode){
    lock = 0;
  }
};

int main(int argc, const char **argv)
{

	DmaDebugRequestProxy *hostDmaDebugRequest = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
	MMUConfigRequestProxy *dmap = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
	DmaManager *dma = new DmaManager(hostDmaDebugRequest, dmap);
	DmaDebugIndication *hostDmaDebugIndication = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
	MMUConfigIndication *hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);

	fprintf(stderr, "Main::allocating memory...\n");

	device = new FlashRequestProxy(IfcNames_FlashRequest);
	FlashIndication *deviceIndication = new FlashIndication(IfcNames_FlashIndication);
	
	srcAlloc = portalAlloc(srcAlloc_sz);
	dstAlloc = portalAlloc(dstAlloc_sz);
	srcBuffer = (unsigned int *)portalMmap(srcAlloc, srcAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz);

	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	fprintf(stderr, "srcAlloc = %x\n", srcAlloc); 
	
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashFreeTagCond, NULL);

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	portalExec_start();
	printf( "Done portalExec_start\n" ); fflush(stdout);

	portalDCacheFlushInval(dstAlloc, dstAlloc_sz, dstBuffer);
	portalDCacheFlushInval(srcAlloc, srcAlloc_sz, srcBuffer);
	ref_dstAlloc = dma->reference(dstAlloc);
	ref_srcAlloc = dma->reference(srcAlloc);

	for (int t = 0; t < NUM_TAGS; t++) {
		readTagTable[t].busy = false;
		writeTagTable[t].busy = false;
		int byteOffset = t * PAGE_SIZE;
		//device->addDmaWriteRefs(ref_dstAlloc, byteOffset, t);
		//device->addDmaReadRefs(ref_srcAlloc, byteOffset, t);
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}
	
	for (int blk=0; blk<BLOCKS_PER_CHIP; blk++) {
		for (int c=0; c<CHIPS_PER_BUS; c++) {
			for (int bus=0; bus< CHIPS_PER_BUS; bus++) {
				flashStatus[bus][c][blk] = UNINIT;
			}
		}
	}


	for (int t = 0; t < NUM_TAGS; t++) {
		for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0;
			writeBuffers[t][i] = 0;
		}
	}

	timespec now;
	unsigned int id = atoi(argv[1]);
	unsigned int jd = atoi(argv[2]);
	unsigned int kd = atoi(argv[3]);
//	for(int id = 1; id <= 1; id*=2) {
//	  for(int jd = 1; jd <= 2; jd*=2) {
//	    for(int kd = 1; kd <= 32; kd*=2) {
	      lock = 1;
              printf("Starting Matrix Multiply %d %d %d\n", id, jd, kd);
              clock_gettime(CLOCK_REALTIME, &starttime);
	      device->setMatrixSize(id, jd, kd, ref_dstAlloc, 47483647);
              while(lock == 1) {};
	      clock_gettime(CLOCK_REALTIME, & now);
	      printf("Done multiply %f\n", timespec_diff_sec(starttime, now));
//	    }
//	  }	
//	}
//        int id, jd, kd;
//        id = atoi(argv[1]);
//        jd = atoi(argv[2]);
//        kd = atoi(argv[3]);
//        clock_gettime(CLOCK_REALTIME, &starttime);
//        printf("Starting Matrix Multiply %d %d %d\n", id, jd, kd);
//	device->setMatrixSize(id, jd, kd, ref_dstAlloc, 47483647);
//        printf("Main thread sleeping\n");
//        while(lock == 1) {};
//	timespec now;
//	clock_gettime(CLOCK_REALTIME, & now);
//	printf("Done multiply %f\n", timespec_diff_sec(starttime, now));

/*
	for ( int t = 0; t < NUM_TAGS; t++ ) {
		for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			fprintf(stderr,  "%x %x %x\n", t, i, readBuffers[t][i] );
		}
	}
	if (testPass==1) {
		fprintf(stderr, "LOG: TEST PASSED!\n");
	}
	else {
		fprintf(stderr, "LOG: **ERROR: TEST FAILED!\n");
	}

*/

}
