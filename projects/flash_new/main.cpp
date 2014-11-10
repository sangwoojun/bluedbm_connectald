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

#define PAGE_SIZE 8192
#define NUM_TAGS 128

FlashRequestProxy *device;

pthread_mutex_t flashReqMutex;
pthread_cond_t flashFreeTagCond;

//8k * 128
size_t dstAlloc_sz = PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
int dstAlloc;
unsigned int ref_dstAlloc; 
unsigned int* dstBuffer;
unsigned int* readBuffers[NUM_TAGS];
bool dstBufBusy[NUM_TAGS]; 

bool verbose = true;
int curReadsInFlight = 0;


double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
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

			pthread_mutex_lock(&flashReqMutex);
			curReadsInFlight --;
			if ( curReadsInFlight < 0 ) {
				fprintf(stderr, "Read requests in flight cannot be negative %d\n", curReadsInFlight );
				curReadsInFlight = 0;
			}
			if ( dstBufBusy[tag] == false ) {
				fprintf(stderr, "**ERROR: received unused buffer read done %d\n", tag);
			}
			dstBufBusy[tag] = false;
			//pthread_cond_broadcast(&flashFreeTagCond);
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void debugDumpResp (unsigned int debug0, unsigned int debug1,  unsigned int debug2, unsigned int debug3) {
			//uint64_t cntHi = debugRdCntHi;
			//uint64_t rdCnt = (cntHi<<32) + debugRdCntLo;
			fprintf(stderr, "DEBUG DUMP: gearSend = %d, gearRec = %d, aurSend = %d, aurRec = %d\n", debug0, debug1, debug2, debug3);
		}


};




int getNumReadsInFlight() { return curReadsInFlight; }

int waitIdleReadBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !dstBufBusy[t] ) {
				dstBufBusy[t] = true;
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



void readPage(int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending read page request with tag=%d @%d %d %d %d\n", tag, bus, chip, block, page );
	device->readPage(bus,chip,block,page,tag);
}


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
	
	dstAlloc = portalAlloc(dstAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz);
	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashFreeTagCond, NULL);

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	portalExec_start();
	printf( "Done portalExec_start\n" ); fflush(stdout);

	portalDCacheFlushInval(dstAlloc, dstAlloc_sz, dstBuffer);
	ref_dstAlloc = dma->reference(dstAlloc);

	for (int t = 0; t < NUM_TAGS; t++) {
		dstBufBusy[t] = false;
		int byteOffset = t * PAGE_SIZE;
		device->addDmaWriteRefs(ref_dstAlloc, byteOffset, t);
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
	}
	
	for (int t = 0; t < NUM_TAGS; t++) {
		for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0;
		}
	}

	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);

	for (int repeat = 0; repeat < 1000000; repeat++){
		//for (int blk = 0; blk < 1; blk++){
		//	for (int chip = 7; chip >= 0; chip--){
		//		for (int bus = 7; bus >= 0; bus--){

				int blk = rand() % 1024;
				int chip = rand() % 8;
				int bus = rand() % 8;
					int page = 0;
					readPage(bus, chip, blk, page, waitIdleReadBuffer());
		//		}
		//	}
		//}
	}
	
	int elapsed = 0;
	while (true) {
		usleep(100);
		if (elapsed == 0) {
			elapsed=10000;
			device->debugDumpReq(0);
		}
		else {
			elapsed--;
		}
		if ( getNumReadsInFlight() == 0 ) break;
	}
	device->debugDumpReq(0);

	clock_gettime(CLOCK_REALTIME, & now);
	printf( "finished reading from page! %f\n", timespec_diff_sec(start, now) );

	for ( int t = 0; t < NUM_TAGS; t++ ) {
		for ( int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			fprintf(stderr,  "%x %x %x\n", t, i, readBuffers[t][i] );
		}
	}
}
