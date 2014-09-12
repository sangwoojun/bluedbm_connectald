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

#include "StdDmaIndication.h"
#include "DmaConfigProxy.h"
#include "GeneratedTypes.h"
#include "FlashIndicationWrapper.h"
#include "FlashRequestProxy.h"

//#include "testmemcpy2.h"

#define TAG_COUNT 128
#define MAX_REQS_INFLIGHT 32

#ifndef BSIM
#define BUFFER_COUNT 16
#define LARGE_NUMBER (1024*1024/8)
#else
#define BUFFER_COUNT 8
#define LARGE_NUMBER 16
#endif

pthread_mutex_t flashReqMutex;
pthread_cond_t flashReqCond;

bool verbose = false;
char* log_prefix = "\t\tLOG: ";

sem_t done_sem;
int srcAllocs[BUFFER_COUNT];
int dstAllocs[BUFFER_COUNT];
unsigned int ref_srcAllocs[BUFFER_COUNT];
unsigned int ref_dstAllocs[BUFFER_COUNT];
unsigned int* srcBuffers[BUFFER_COUNT];
unsigned int* dstBuffers[BUFFER_COUNT];
bool srcBufferBusy[BUFFER_COUNT];
bool readTagBusy[TAG_COUNT];

int numBytes = 1 << (10+5); // 32KB buffer, to be safe
size_t alloc_sz = numBytes*sizeof(unsigned char);

int curReqsInFlight = 0;
std::list<int> finishedReadBuffer;
std::list<int> readyReadBuffer;

pthread_mutex_t freeListMutex;
void setFinishedReadBuffer(int idx) {
	pthread_mutex_lock(&freeListMutex);
	finishedReadBuffer.push_front(idx);
	pthread_mutex_unlock(&freeListMutex);
}
void flushFinishedReadBuffers(FlashRequestProxy* device) {
	pthread_mutex_lock(&freeListMutex);
	while(!finishedReadBuffer.empty()) {
		int finishedread = finishedReadBuffer.back();
		if ( verbose ) printf( "%s returning read buffer %d\n", log_prefix, finishedread );
		device->returnReadHostBuffer(finishedread);
		finishedReadBuffer.pop_back();
	}
	pthread_mutex_unlock(&freeListMutex);
}
int popReadyReadBuffer() {
	pthread_mutex_lock(&freeListMutex);
	int ret = -1;
	if ( !readyReadBuffer.empty() ) {
		ret = readyReadBuffer.back();
		readyReadBuffer.pop_back();
	}
	pthread_mutex_unlock(&freeListMutex);
	return ret;
}

class FlashIndication : public FlashIndicationWrapper
{

public:
  FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

  virtual void writeDone(unsigned int bufidx) {
	pthread_mutex_lock(&flashReqMutex);

	curReqsInFlight --;
	if ( curReqsInFlight < 0 ) {
		curReqsInFlight = 0;
		fprintf(stderr, "Requests in flight cannot be negative\n" );
	}

	srcBufferBusy[bufidx] = false;
	if ( verbose ) printf( "%s received write done buffer: %d \n", log_prefix, bufidx );

	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);
  }
  virtual void readDone(unsigned int rbuf, unsigned int tag) {
	pthread_mutex_lock(&flashReqMutex);

	curReqsInFlight --;
	if ( curReqsInFlight < 0 ) {
		curReqsInFlight = 0;
		fprintf(stderr, "Requests in flight cannot be negative\n" );
	}
	readyReadBuffer.push_front(rbuf);
	if ( verbose ) printf( "%s received read page tag: %d buffer: %d\n", log_prefix, tag, rbuf );

	readTagBusy[tag] = false;
	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);
  }
  virtual void hexDump(unsigned int data) {
  	printf( "%x--\n", data );
	fflush(stdout);
  }
};

int getNumReqsInFlight() { return curReqsInFlight; }

void writePage(FlashRequestProxy* device, int channel, int chip, int block, int page, int bufidx) {
	if ( bufidx > BUFFER_COUNT ) return;

	pthread_mutex_lock(&flashReqMutex);
	if ( verbose ) printf( "%s requesting write page\n", log_prefix );
	
	while (curReqsInFlight >= MAX_REQS_INFLIGHT ) {
		pthread_cond_wait(&flashReqCond, &flashReqMutex);
	}

	if ( verbose ) printf( "%s sending write req to device\n", log_prefix );
	curReqsInFlight ++;
	device->writePage(channel,chip,block,page,bufidx);

	pthread_mutex_unlock(&flashReqMutex);
}

int getIdleWriteBuffer() {
	pthread_mutex_lock(&flashReqMutex);

	int ret = -1;
	for ( int i = 0; i < BUFFER_COUNT; i++ ) {
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
	while (bufidx == -1) bufidx = getIdleWriteBuffer();

	if ( verbose ) printf( "%s idle write buffer discovered %d\n", log_prefix, bufidx );
	return bufidx;
}


void readPage(FlashRequestProxy* device, int channel, int chip, int block, int page) {
	pthread_mutex_lock(&flashReqMutex);
	while (curReqsInFlight >= MAX_REQS_INFLIGHT ) {
		pthread_cond_wait(&flashReqCond, &flashReqMutex);
	}
	int availTag = -1;
	if ( verbose ) printf( "%s finding new tag\n", log_prefix );
	while (true) {
		flushFinishedReadBuffers(device);

		availTag = -1;
		for ( int i = 0; i < TAG_COUNT; i++ ) {
			if ( readTagBusy[i] == false ) {
				availTag = i;
				break;
			}
		}
		if ( availTag < 0 ) {
			if ( verbose ) printf( "%s no tags!\n", log_prefix );
			pthread_cond_wait(&flashReqCond, &flashReqMutex);
		} else {
			break;
		}
	}
	curReqsInFlight ++;
	readTagBusy[availTag] = true;

	if ( verbose ) printf( "%s sending read page request\n", log_prefix );
	device->readPage(channel,chip,block,page,availTag);
	pthread_mutex_unlock(&flashReqMutex);
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

	for ( int i = 0; i < BUFFER_COUNT; i++ ) {
		srcAllocs[i] = portalAlloc(alloc_sz);
		dstAllocs[i] = portalAlloc(alloc_sz);
		srcBuffers[i] = (unsigned int *)portalMmap(srcAllocs[i], alloc_sz);
		dstBuffers[i] = (unsigned int *)portalMmap(dstAllocs[i], alloc_sz);
	}
	portalExec_start();
	for ( int i = 0; i < BUFFER_COUNT; i++ ) {
		portalDCacheFlushInval(srcAllocs[i], alloc_sz, srcBuffers[i]);
		portalDCacheFlushInval(dstAllocs[i], alloc_sz, dstBuffers[i]);
		ref_srcAllocs[i] = dma->reference(srcAllocs[i]);
		ref_dstAllocs[i] = dma->reference(dstAllocs[i]);
	}

	// Storage system init /////////////////////////////////
	curReqsInFlight = 0;
	pthread_mutex_init(&freeListMutex, NULL);
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashReqCond, NULL);

	for ( int i = 0; i < BUFFER_COUNT; i++ ) {
		srcBufferBusy[i] = false;
		device->addReadHostBuffer(ref_dstAllocs[i], i);
		device->addWriteHostBuffer(ref_srcAllocs[i], i);
	}
	for ( int i = 0; i > TAG_COUNT; i++ ) {
		readTagBusy[i] = false;
	}
	/////////////////////////////////////////////////////////

	fprintf(stderr, "Main::flush and invalidate complete\n");
  
	device->sendTest(8192);

	for ( int i = 0; i < (8192+64)/4; i++ ) {
		for ( int j = 0; j < BUFFER_COUNT; j++ ) {
			dstBuffers[j][i] = 8192/4-i;
			srcBuffers[j][i] = i;
		}
	}

	for ( int i = 0; i < LARGE_NUMBER; i++ ) writePage(device, 0,0,0,i,waitIdleWriteBuffer());

	while ( getNumReqsInFlight() > 0 ) usleep(1000);

	printf( "wrote pages to flash!\n" );
  
	for ( int i = 0; i < LARGE_NUMBER; i++ ) {
		readPage(device, 0,0,0,i);
	}
	
	printf( "trying reading from page!\n" );

	while (true) {
		int rrb = popReadyReadBuffer();
		while (rrb >= 0 ) {
			setFinishedReadBuffer(rrb);
			rrb = popReadyReadBuffer();
		}

		flushFinishedReadBuffers(device);
		if ( getNumReqsInFlight() == 0 ) break;
	}
	printf( "finished reading from page!\n" );

	for ( int i = 0; i < (8192+64)/4; i++ ) {
		for ( int j = 0; j < BUFFER_COUNT; j++ ) {
			if ( i > (8192+64)/4 - 32 )
			printf( "%d %d %d\n", j, i, dstBuffers[j][i] );
		}
	}

	exit(0);
}
