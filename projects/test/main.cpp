/* Copyright (c) 2013 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
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
#include "DmaConfigProxy.h"
#include "GeneratedTypes.h"
#include "FlashIndicationWrapper.h"
#include "FlashRequestProxy.h"

#define TAG_COUNT 64
//#define MAX_REQS_INFLIGHT 32

#ifndef BSIM
#define DMA_BUFFER_COUNT 16
#define LARGE_NUMBER (1024*1024/8)
bool verbose = false;
#else
#define DMA_BUFFER_COUNT 8
#define LARGE_NUMBER 512
bool verbose = true;
#endif

#define READ_BUFFER_WAYS (128/DMA_BUFFER_COUNT)
#define WRITE_BUFFER_WAYS (64/DMA_BUFFER_COUNT)
#define READ_BUFFER_COUNT (DMA_BUFFER_COUNT*READ_BUFFER_WAYS)
#define WRITE_BUFFER_COUNT (DMA_BUFFER_COUNT*WRITE_BUFFER_WAYS)

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}

pthread_mutex_t flashReqMutex;
pthread_cond_t flashReqCond;

char* log_prefix = "\t\tLOG: ";

sem_t done_sem;
int srcAllocs[DMA_BUFFER_COUNT];
int dstAllocs[DMA_BUFFER_COUNT];
unsigned int ref_srcAllocs[DMA_BUFFER_COUNT];
unsigned int ref_dstAllocs[DMA_BUFFER_COUNT];
unsigned int* srcBuffers[DMA_BUFFER_COUNT];
unsigned int* dstBuffers[DMA_BUFFER_COUNT];
bool srcBufferBusy[WRITE_BUFFER_COUNT];
bool readTagBusy[TAG_COUNT];

unsigned int* writeBuffers[WRITE_BUFFER_COUNT];
unsigned int* readBuffers[READ_BUFFER_COUNT];

int rnumBytes = (1 << (10 +4))*READ_BUFFER_WAYS; //16KB buffer, to be safe
int wnumBytes = (1 << (10 +4))*WRITE_BUFFER_WAYS; //16KB buffer, to be safe
size_t ralloc_sz = rnumBytes*sizeof(unsigned char);
size_t walloc_sz = wnumBytes*sizeof(unsigned char);

int curWritesInFlight = 0;
int curReadsInFlight = 0;
std::list<int> finishedReadBuffer;
typedef struct { int bufidx; int tag; } bufferId;
std::list<bufferId> readyReadBuffer;

unsigned int noCmdBudgetCount = 0;
unsigned int noTagCount = 0;

pthread_mutex_t freeListMutex;
pthread_cond_t freeListCond;
pthread_mutex_t cmdReqMutex;
pthread_cond_t cmdReqCond;
void setFinishedReadBuffer(int idx) {
	//pthread_mutex_lock(&freeListMutex);
	finishedReadBuffer.push_front(idx);
	//pthread_mutex_unlock(&freeListMutex);
}
void flushFinishedReadBuffers(FlashRequestProxy* device) {
	//pthread_mutex_lock(&freeListMutex);
	while(!finishedReadBuffer.empty()) {
		int finishedread = finishedReadBuffer.back();
		if ( verbose ) printf( "%s returning read buffer %d\n", log_prefix, finishedread );
		device->returnReadHostBuffer(finishedread);
		finishedReadBuffer.pop_back();
	}
	//pthread_mutex_unlock(&freeListMutex);
}
bufferId popReadyReadBuffer() {
	//pthread_mutex_lock(&freeListMutex);
	bufferId ret;
	ret.bufidx = -1;
	ret.tag = -1;
	if ( !readyReadBuffer.empty() ) {
		ret = readyReadBuffer.back();
		readyReadBuffer.pop_back();
	}
	//pthread_mutex_unlock(&freeListMutex);
	return ret;
}


timespec readstart[TAG_COUNT];
int readstartidx = 0;
int readdoneidx = 0;
timespec readnow;

int timecheckidx = 0;
float timecheck[2048];

int curCmdCountBudget = 0;
class FlashIndication : public FlashIndicationWrapper
{

public:
  FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

  virtual void writeDone(unsigned int bufidx) {
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight --;
	srcBufferBusy[bufidx] = false;
	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);
	
	if ( curWritesInFlight < 0 ) {
		curWritesInFlight = 0;
		fprintf(stderr, "Write requests in flight cannot be negative\n" );
	}

/*
	curReqsInFlight --;
	if ( curReqsInFlight < 0 ) {
		curReqsInFlight = 0;
		fprintf(stderr, "Requests in flight cannot be negative\n" );
	}
*/
	if ( verbose ) printf( "%s received write done buffer: %d curWritesInFlight: %d\n", log_prefix, bufidx, curWritesInFlight );

  }
  virtual void readDone(unsigned int rbuf, unsigned int tag) {
	if ( verbose ) printf( "%s received read page tag: %d buffer: %d %d\n", log_prefix, tag, rbuf, curReadsInFlight );
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight --;
	if ( tag < TAG_COUNT ) readTagBusy[tag] = false;
	else fprintf(stderr, "WARNING: done tag larger than tag count\n" );
	pthread_mutex_lock(&freeListMutex);
	bufferId tbi; tbi.bufidx = rbuf; tbi.tag = tag;
	readyReadBuffer.push_front(tbi);
	pthread_cond_broadcast(&freeListCond);
	pthread_mutex_unlock(&freeListMutex);

	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);

	if ( curReadsInFlight < 0 ) {
		curReadsInFlight = 0;
		fprintf(stderr, "Read requests in flight cannot be negative\n" );
	}
	if ( verbose ) printf( "%s Finished pagedone: %d buffer: %d %d\n", log_prefix, tag, rbuf, curReadsInFlight );

	if ( timecheckidx < 2048 ) {
		clock_gettime(CLOCK_REALTIME, & readnow);
		timecheck[timecheckidx] = timespec_diff_sec(readstart[readdoneidx], readnow);
		readdoneidx++;
		if ( readdoneidx >= TAG_COUNT ) readdoneidx = 0;
		timecheckidx ++;
	}


/*
	curReqsInFlight --;
	if ( curReqsInFlight < 0 ) {
		curReqsInFlight = 0;
		fprintf(stderr, "Requests in flight cannot be negative\n" );
	}
	*/

  }

  virtual void reqFlashCmd(unsigned int inQ, unsigned int count) {
	if ( verbose ) printf( "\t%s increase flash cmd budget: %d (%d)\n", log_prefix, curCmdCountBudget, inQ );
	pthread_mutex_lock(&cmdReqMutex);
	curCmdCountBudget += count;
	pthread_cond_broadcast(&cmdReqCond);
	pthread_mutex_unlock(&cmdReqMutex);

  }

  timespec aurorastart;
  virtual void hexDump(unsigned int data) {
  	printf( "%x--\n", data );
	timespec now;
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "aurora data! %f\n", timespec_diff_sec(aurorastart, now) );
	fflush(stdout);
  }
};

int getNumWritesInFlight() { return curWritesInFlight; }
int getNumReadsInFlight() { return curReadsInFlight; }

void writePage(FlashRequestProxy* device, int channel, int chip, int block, int page, int bufidx) {
	if ( bufidx > WRITE_BUFFER_COUNT ) return;

	if ( verbose ) printf( "%s requesting write page\n", log_prefix );


	pthread_mutex_lock(&cmdReqMutex);
	while (curCmdCountBudget <= 0) {
		noCmdBudgetCount++;
		if ( verbose ) printf( "%s no cmd budget \n", log_prefix );
		pthread_cond_wait(&cmdReqCond, &cmdReqMutex);
	}
	curCmdCountBudget--; 
	pthread_mutex_unlock(&cmdReqMutex);


	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) printf( "%s sending write req to device %d\n", log_prefix, curWritesInFlight );
	device->writePage(channel,chip,block,page,bufidx);

}

int getIdleWriteBuffer() {
	pthread_mutex_lock(&flashReqMutex);

	int ret = -1;
	for ( int i = 0; i < WRITE_BUFFER_COUNT; i++ ) {
		if ( !srcBufferBusy[i] ) {
			srcBufferBusy[i] = true;
			ret = i;
			break;
		}
	}
	pthread_mutex_unlock(&flashReqMutex);
	return ret;
}

int waitIdleWriteBuffer() {
	int bufidx = -1;
	pthread_mutex_lock(&flashReqMutex);

	while (bufidx < 0) {
		for ( int i = 0; i < WRITE_BUFFER_COUNT; i++ ) {
			if ( !srcBufferBusy[i] ) {
				bufidx = i;
				break;
			}
		}
		if ( bufidx == -1 ) {
			pthread_cond_wait(&flashReqCond, &flashReqMutex);
		}
	}

	pthread_mutex_unlock(&flashReqMutex);
	if ( verbose ) printf( "%s idle write buffer discovered %d\n", log_prefix, bufidx );

	return bufidx;
}



void readPage(FlashRequestProxy* device, int channel, int chip, int block, int page) {

	clock_gettime(CLOCK_REALTIME, & readstart[readstartidx]);
	readstartidx++;
	if ( readstartidx >= TAG_COUNT ) readstartidx = 0;

	pthread_mutex_lock(&cmdReqMutex);
	while (curCmdCountBudget <= 0) {
		noCmdBudgetCount++;
		if ( verbose ) printf( "%s no cmd budget \n", log_prefix );
		pthread_cond_wait(&cmdReqCond, &cmdReqMutex);
	}
	curCmdCountBudget --;
	pthread_mutex_unlock(&cmdReqMutex);



	int availTag = -1;
	if ( verbose ) printf( "%s budget: %d finding new tag\n", log_prefix, curCmdCountBudget );
	pthread_mutex_lock(&flashReqMutex);
	while (true) {

		if ( verbose ) printf( "%s finding new tag\n", log_prefix );
		availTag = -1;
		for ( int i = 0; i < TAG_COUNT; i++ ) {
			if ( readTagBusy[i] == false ) {
				availTag = i;
				curReadsInFlight ++;
				readTagBusy[availTag] = true;
				break;
			}
		}

		if ( availTag < 0 ) {
			if ( verbose ) printf( "%s no tags!\n", log_prefix );
			noTagCount++;
			pthread_cond_wait(&flashReqCond, &flashReqMutex);
			//usleep(100);
		} else {
			pthread_cond_broadcast(&flashReqCond);
			pthread_mutex_unlock(&flashReqMutex);
			break;
		}
	}
	
	//if ( verbose ) printf( "%s using tag %d\n", log_prefix, availTag );


	//curReqsInFlight ++;

	if ( verbose ) printf( "%s sending read page request with tag %d\n", log_prefix, availTag );
	device->readPage(channel,chip,block,page,availTag);
}

static void* return_finished_readbuffer(void* arg) {
	FlashRequestProxy *device = (FlashRequestProxy*) arg;
	while(true) {
		pthread_mutex_lock(&freeListMutex);
		bufferId bid = popReadyReadBuffer();
		int rrb = bid.bufidx;
		while (rrb >= 0 ) {
			setFinishedReadBuffer(rrb);
			rrb = popReadyReadBuffer().bufidx;
		}
		flushFinishedReadBuffers(device);
		pthread_cond_wait(&freeListCond, &freeListMutex);
		pthread_mutex_unlock(&freeListMutex);
	}
}

int main(int argc, const char **argv)
{
	FlashRequestProxy *device = 0;
	DmaConfigProxy *dmap = 0;

	FlashIndication *deviceIndication = 0;
	DmaIndication *dmaIndication = 0;

	if(sem_init(&done_sem, 1, 0)){
		fprintf(stderr, "failed to init done_sem\n");
		exit(1);
	}

	fprintf(stderr, "%s %s\n", __DATE__, __TIME__);

	device = new FlashRequestProxy(IfcNames_FlashRequest);
	dmap = new DmaConfigProxy(IfcNames_DmaConfig);
	DmaManager *dma = new DmaManager(dmap);

	deviceIndication = new FlashIndication(IfcNames_FlashIndication);
	dmaIndication = new DmaIndication(dma, IfcNames_DmaIndication);

	fprintf(stderr, "Main::allocating memory...\n");

	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		srcAllocs[i] = portalAlloc(walloc_sz);
		dstAllocs[i] = portalAlloc(ralloc_sz);
		srcBuffers[i] = (unsigned int *)portalMmap(srcAllocs[i], walloc_sz);
		dstBuffers[i] = (unsigned int *)portalMmap(dstAllocs[i], ralloc_sz);
	}
	portalExec_start();
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		portalDCacheFlushInval(srcAllocs[i], walloc_sz, srcBuffers[i]);
		portalDCacheFlushInval(dstAllocs[i], ralloc_sz, dstBuffers[i]);
		ref_srcAllocs[i] = dma->reference(srcAllocs[i]);
		ref_dstAllocs[i] = dma->reference(dstAllocs[i]);
	}

	// Storage system init /////////////////////////////////
	curWritesInFlight = 0;
	curCmdCountBudget = 0;
	pthread_mutex_init(&freeListMutex, NULL);
	pthread_cond_init(&freeListCond, NULL);
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_mutex_init(&cmdReqMutex, NULL);
	pthread_cond_init(&flashReqCond, NULL);
	pthread_cond_init(&cmdReqCond, NULL);

	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < WRITE_BUFFER_WAYS; j++ ) {
			int idx = i*WRITE_BUFFER_WAYS+j;
			srcBufferBusy[idx] = false;

			int offset = j*1024*16;
			device->addWriteHostBuffer(ref_srcAllocs[i], offset, idx);
			writeBuffers[idx] = srcBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < READ_BUFFER_WAYS; j++ ) {
			int idx = i*READ_BUFFER_WAYS+j;

			int offset = j*1024*16;
			device->addReadHostBuffer(ref_dstAllocs[i], offset, idx);
			readBuffers[idx] = dstBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
	for ( int i = 0; i > TAG_COUNT; i++ ) {
		readTagBusy[i] = false;
	}

	pthread_t ftid;
	pthread_create(&ftid, NULL, return_finished_readbuffer, (void*)device);
	/////////////////////////////////////////////////////////

	fprintf(stderr, "Main::flush and invalidate complete\n");
  
	clock_gettime(CLOCK_REALTIME, & deviceIndication->aurorastart);
	device->sendTest(LARGE_NUMBER*1024);

	for ( int j = 0; j < WRITE_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			writeBuffers[j][i] = i;
		}
	}
	for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			readBuffers[j][i] = 8192/4-i;
		}
	}
	device->start(0);

	timespec start, now;


	printf( "writing pages to flash!\n" );
	clock_gettime(CLOCK_REALTIME, & start);
	for ( int i = 0; i < LARGE_NUMBER/4; i++ ) {
		for ( int j = 0; j < 4; j++ ) {
			if ( i % 1024 == 0 ) 
				printf( "writing page %d\n", i );
			writePage(device, j,0,0,i,waitIdleWriteBuffer());
		}
	}
	printf( "waiting for writing pages to flash!\n" );
	while ( getNumWritesInFlight() > 0 ) usleep(1000);
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "finished writing to page! %f\n", timespec_diff_sec(start, now) );

	printf( "wrote pages to flash!\n" );
  

	clock_gettime(CLOCK_REALTIME, & start);
	for ( int i = 0; i < LARGE_NUMBER/4; i++ ) {
		for ( int j = 0; j < 4; j++ ) {

			readPage(device, j,0,0,i);
			if ( i % 1024 == 0 ) 
				printf( "reading page %d\n", i );
		}
	}
	
	printf( "trying reading from page!\n" );

	while (true) {
	/*
		pthread_mutex_lock(&freeListMutex);
		bufferId bid = popReadyReadBuffer();
		int rrb = bid.bufidx;
		while (rrb >= 0 ) {
			setFinishedReadBuffer(rrb);
			rrb = popReadyReadBuffer().bufidx;
		}

		flushFinishedReadBuffers(device);
		pthread_cond_wait(&freeListCond, &freeListMutex);
		pthread_mutex_unlock(&freeListMutex);
		*/

		usleep(100);
		if ( getNumReadsInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "finished reading from page! %f\n", timespec_diff_sec(start, now) );

	for ( int i = 0; i < (8192+64)/4; i++ ) {
		for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
			if ( i > (8192+64)/4 - 2 )
			printf( "%d %d %d\n", j, i, readBuffers[j][i] );
		}
	}
	for ( int i = 0; i < 2048; i++ ) {
		printf( "%d: %f\n", i, timecheck[i] );
	}
	printf( "Command buget was gone:%d \nTag was busy:%d\n", noCmdBudgetCount, noTagCount );

	exit(0);
}
