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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h> 

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "FlashIndication.h"
#include "FlashRequest.h"

#define PAGES_PER_BLOCK 1
#define BLOCKS_PER_CHIP 8
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8
#define NUM_NODES 10

#define DST_NODE 1

#define PAGE_SIZE (8192*2)
#define PAGE_SIZE_VALID (8224)
#define NUM_TAGS 128

bool verbose = false;
bool doerasewrites = false; //do this only if sending to self

typedef enum {
	UNINIT,
	ERASED,
	WRITTEN
} FlashStatusT;

typedef struct {
	bool busy;
	int node;
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
FlashStatusT flashStatus[NUM_NODES][NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];

int testPass = 1;
int curReadsInFlight = 0;
int curWritesInFlight = 0;
int curErasesInFlight = 0;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}


unsigned int hashAddrToData(int node, int bus, int chip, int blk, int word) {
	//return ((node<<27) + (bus<<24) + (chip<<20) + (blk<<16) + word);
	return ((bus<<24) + (chip<<20) + (blk<<16) + word);
}


bool checkReadData(int tag) {
	TagTableEntry e = readTagTable[tag];
	int goldenData;
	if (flashStatus[e.node][e.bus][e.chip][e.block]==WRITTEN) {
		int numErrors = 0;
		for (int word=0; word<PAGE_SIZE_VALID/sizeof(unsigned int); word++) {
			goldenData = hashAddrToData(e.node, e.bus, e.chip, e.block, word);
			if (goldenData != readBuffers[tag][word]) {
				fprintf(stderr, "LOG: **ERROR: read data mismatch [%d]! Expected: %x, read: %x\n", word, goldenData, readBuffers[tag][word]);
				numErrors++; 
				testPass = 0;
			}
		}
		if (numErrors==0) {
			fprintf(stderr, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.node][e.bus][e.chip][e.block]==ERASED) {
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

class FlashIndication : public FlashIndicationWrapper
{

	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

		virtual void readDone(unsigned int tag) {

			if ( verbose ) {
				//printf( "%s received read page buffer: %d %d\n", log_prefix, rbuf, curReadsInFlight );
				printf( "LOG: pagedone: tag=%d; inflight=%d\n", tag, curReadsInFlight );
				fflush(stdout);
			}

			//check 
			if (verbose) {
				checkReadData(tag);
			}

			pthread_mutex_lock(&flashReqMutex);
			curReadsInFlight --;
			if ( curReadsInFlight < 0 ) {
				fprintf(stderr, "LOG: **ERROR: Read requests in flight cannot be negative %d\n", curReadsInFlight );
				curReadsInFlight = 0;
			}
			if ( readTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused buffer read done %d\n", tag);
				testPass = 0;
			}
			readTagTable[tag].busy = false;
			//pthread_cond_broadcast(&flashFreeTagCond);
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void writeDone(unsigned int tag) {
			if (verbose) {
				printf("LOG: writedone, tag=%d\n", tag); fflush(stdout);
			}
			//TODO probably should use a diff lock
			pthread_mutex_lock(&flashReqMutex);
			curWritesInFlight--;
			if ( curWritesInFlight < 0 ) {
				fprintf(stderr, "LOG: **ERROR: Write requests in flight cannot be negative %d\n", curWritesInFlight );
				curWritesInFlight = 0;
			}
			if ( writeTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused buffer Write done %d\n", tag);
				testPass = 0;
			}
			writeTagTable[tag].busy = false;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void eraseDone(unsigned int tag, unsigned int status) {
			printf("LOG: eraseDone, tag=%d, status=%d\n", tag, status); fflush(stdout);
			pthread_mutex_lock(&flashReqMutex);
			if (status != 0) {
				TagTableEntry e = eraseTagTable[tag];
				printf("LOG: detected bad block with tag=%d node=%d @%d %d %d 0\n", tag, e.node, e.bus, e.chip, e.block);
			}

			curErasesInFlight--;
			if ( curErasesInFlight < 0 ) {
				fprintf(stderr, "LOG: **ERROR: erase requests in flight cannot be negative %d\n", curErasesInFlight );
				curErasesInFlight = 0;
			}
			if ( eraseTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused tag erase done %d\n", tag);
				testPass = 0;
			}
			eraseTagTable[tag].busy = false;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void debugDumpResp (unsigned int debug0, unsigned int debug1,  unsigned int debug2, unsigned int debug3, unsigned int debug4, unsigned int debug5) {
			//uint64_t cntHi = debugRdCntHi;
			//uint64_t rdCnt = (cntHi<<32) + debugRdCntLo;
			fprintf(stderr, "LOG: DEBUG DUMP: gearSend = %d, gearRec = %d, aurSend = %d, aurRec = %d, readSend=%d, writeSend=%d\n", debug0, debug1, debug2, debug3, debug4, debug5);
		}

		virtual void debugAuroraExt(unsigned int debug0, unsigned int debug1, unsigned int debug2, unsigned int debug3) {
			fprintf(stderr, "LOG: Aurora Ext: cmdHi = %x, cmdLo = %x\n", debug0, debug1);
		}
		
		virtual void hexDump(unsigned int hex) {
			fprintf(stderr, "LOG: hexDump=%x\n", hex);
		}


};




int getNumReadsInFlight() { return curReadsInFlight; }
int getNumWritesInFlight() { return curWritesInFlight; }
int getNumErasesInFlight() { return curErasesInFlight; }



//TODO: more efficient locking
int waitIdleEraseTag() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !eraseTagTable[t].busy ) {
				eraseTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}


//TODO: more efficient locking
int waitIdleWriteBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !writeTagTable[t].busy) {
				writeTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}



//TODO: more efficient locking
int waitIdleReadBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t=t+1 ) { //FIXME
			if ( !readTagTable[t].busy ) {
				readTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}


void eraseBlock(int node, int bus, int chip, int block, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curErasesInFlight ++;
	eraseTagTable[tag].node = node;
	eraseTagTable[tag].bus = bus;
	eraseTagTable[tag].chip = chip;
	eraseTagTable[tag].block = block;
	flashStatus[node][bus][chip][block] = ERASED;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending erase block request with tag=%d to node=%d @%d %d %d 0\n", tag, node, bus, chip, block );
	device->eraseBlock(node,bus,chip,block,tag);
}



void writePage(int node, int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight ++;
	flashStatus[node][bus][chip][block] = WRITTEN;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending write page request with tag=%d @%d %d %d %d\n", tag, bus, chip, block, page );
	device->writePage(node,bus,chip,block,page,tag);
}

void readPage(int node, int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	//FIXME add node
	readTagTable[tag].node = node;
	readTagTable[tag].bus = bus;
	readTagTable[tag].chip = chip;
	readTagTable[tag].block = block;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending read page request to node=%d with tag=%d @%d %d %d %d\n", node, tag, bus, chip, block, page );
	device->readPage(node,bus,chip,block,page,tag);
}


void auroraifc_start(int myid) {
	device->setNetId(myid);
	device->auroraStatus(0);

	sleep(1);
}








int main(int argc, const char **argv)
{

	//Getting my ID
	char hostname[32];
	gethostname(hostname,32);


	int myid = atoi(hostname+strlen("bdbm"));
	if ( strstr(hostname, "bdbm") == NULL 
		&& strstr(hostname, "umma") == NULL
		&& strstr(hostname, "lightning") == NULL ) {
			myid = 0;
	}
	char* userhostid = getenv("BDBM_ID");
	if ( userhostid != NULL ) {
		myid = atoi(userhostid);
	}

	fprintf(stderr, "Main: myid=%d\n", myid);

	MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
	MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
	DmaManager *dma = new DmaManager(dmap);
	MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
	MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

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

	device->setDmaWriteRef(ref_dstAlloc);
	device->setDmaReadRef(ref_srcAlloc);
	for (int t = 0; t < NUM_TAGS; t++) {
		readTagTable[t].busy = false;
		writeTagTable[t].busy = false;
		int byteOffset = t * PAGE_SIZE;
		printf("byteOffset=%x\n", byteOffset); fflush(stdout);
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}
	
	for (int node=0; node<NUM_NODES; node++) {
		for (int blk=0; blk<BLOCKS_PER_CHIP; blk++) {
			for (int c=0; c<CHIPS_PER_BUS; c++) {
				for (int bus=0; bus< CHIPS_PER_BUS; bus++) {
					flashStatus[node][bus][c][blk] = UNINIT;
				}
			}
		}
	}


	for (int t = 0; t < NUM_TAGS; t++) {
		for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0;
			writeBuffers[t][i] = 0;
		}
	}


	//Start ext aurora
	auroraifc_start(myid);

	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	device->debugDumpReq(0);
	sleep(1);
	device->debugDumpReq(0);
	sleep(1);



	if (myid==3) {

		
		timespec start, now;
		double timeElapsed = 0;
		int node = myid; //FIXME: modify this

		if (doerasewrites) {
			//test erases
			//for (int node=NUM_NODES-1; node >= 1; node--) 
			//for (int node=DST_NODE; node == DST_NODE; node++) 
				for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
					for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
						for (int bus = 0; bus < NUM_BUSES; bus++){
							eraseBlock(node, bus, chip, blk, waitIdleEraseTag());
						}
					}
				}

			while (true) {
				usleep(100);
				if ( getNumErasesInFlight() == 0 ) break;
			}


			//read back erased pages
			//for (int node=NUM_NODES-1; node >= 1; node--) 
			//for (int node=DST_NODE; node == DST_NODE; node++) 
				for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
					for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
						for (int bus = 0; bus < NUM_BUSES; bus++){
							int page = 0;
							readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
						}
					}
				}

			while (true) {
				usleep(100);
				if ( getNumReadsInFlight() == 0 ) break;
			}
			

			//write pages
			//FIXME: in old xbsv, simulatneous DMA reads using multiple readers cause kernel panic
			//Issue each bus separately for now

			int pagesWritten = 0;
			clock_gettime(CLOCK_REALTIME, & start);
			//for (int node=NUM_NODES-1; node >= 1; node--) 
			//for (int node=DST_NODE; node == DST_NODE; node++) 
				for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
					for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
						for (int bus = 0; bus < NUM_BUSES; bus++){
							int page = 0;
							//get free tag
							int freeTag = waitIdleWriteBuffer();
							//fill write memory
							for (int w=0; w<PAGE_SIZE/sizeof(unsigned int); w++) {
								writeBuffers[freeTag][w] = hashAddrToData(node, bus, chip, blk, w);
							}
							//send request
							writePage(node, bus, chip, blk, page, freeTag); 
							pagesWritten++;
						}
					}
				}
			while (true) {
				usleep(100);
				if ( getNumWritesInFlight() == 0 ) break;
			}

			clock_gettime(CLOCK_REALTIME, & now);
			timeElapsed = timespec_diff_sec(start, now);
			fprintf(stderr, "LOG: finished writing! time=%f, numPages=%d, bandwidth=%f MB/s\n", timeElapsed, pagesWritten, (pagesWritten*8)/timeElapsed/1024  );

		} //doerasewrites


		/*
		for (int numPts=0; numPts<100; numPts++) {
			int node = DST_NODE;
			int bus = rand()%NUM_BUSES;
			int chip = rand()%CHIPS_PER_BUS;
			int blk = rand()%BLOCKS_PER_CHIP;
			int page = rand()%PAGES_PER_BLOCK;
			clock_gettime(CLOCK_REALTIME, & start);
			for (int repeat = 0; repeat < 100; repeat++){
				int page = 0;
				readPage(node, bus, chip, blk, page, waitIdleReadBuffer());

			}
			while (true) {
				if ( getNumReadsInFlight() == 0 ) break;
				usleep(100);
			}
		}
		*/
	
		sleep(1);
	
		int pagesRead = 0;
		clock_gettime(CLOCK_REALTIME, & start);
		
	
		//for (int node=NUM_NODES-1; node >= 1; node--) {
		//for (int node=DST_NODE; node == DST_NODE; node++) {
		for (int repeat = 0; repeat < 100; repeat++){
			for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
				for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
					for (int bus = 0; bus < NUM_BUSES; bus++){
						pagesRead++;
						int page = 0;
						readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
					}
				}
			}
		}
		//}

		while (true) {
			if ( getNumReadsInFlight() == 0 ) break;
			usleep(100);
		}

		clock_gettime(CLOCK_REALTIME, & now);
		timeElapsed = timespec_diff_sec(start, now);
		fprintf(stderr, "LOG: finished reading from page! time=%f, numPages=%d, bandwidth=%f MB/s\n", timeElapsed, pagesRead, (pagesRead*8)/timeElapsed/1024  );


		device->debugDumpReq(0);
		sleep(5);
		


		for ( int t = 0; t < NUM_TAGS; t++ ) {
			for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
				fprintf(stderr,  "%x %x %x\n", t, i, readBuffers[t][i] );
			}
		}
		if (!verbose) {
			fprintf(stderr, "LOG: DONE! data check skipped\n");
		} 
		else if (testPass==1) {
			fprintf(stderr, "LOG: TEST PASSED!\n");
		}
		else {
			fprintf(stderr, "LOG: **ERROR: TEST FAILED!\n");
		}
		

	} 
	else {
		fprintf(stderr, "Sleeping infinitely...\n");
		while (true) {
		device->debugDumpReq(0);
		sleep(1);
		}
		sleep(1000000);
	}
}








//BEGIN: spot test
/*
		//[1] 7 0 63 0
		int node = 1;
		int bus = 7;
		int chip = 0;
		int blk = 63;
		int page = 0;


		eraseBlock(node, bus, chip, blk, waitIdleEraseTag());
		while (true) {
			usleep(100);
			if ( getNumErasesInFlight() == 0 ) break;
		}

		int freeTag = waitIdleWriteBuffer();
		//fill write memory
		for (int w=0; w<PAGE_SIZE/sizeof(unsigned int); w++) {
			writeBuffers[freeTag][w] = hashAddrToData(node, bus, chip, blk, w);
		}
		//send request
		writePage(node, bus, chip, blk, page, freeTag);
		while (true) {
			usleep(100);
			if ( getNumWritesInFlight() == 0 ) break;
		}

		readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
		while (true) {
			usleep(100);
			if ( getNumReadsInFlight() == 0 ) break;
		}
//END: spot test
*/
