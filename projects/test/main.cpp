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

#include "StdDmaIndication.h"
#include "DmaConfigProxy.h"
#include "GeneratedTypes.h"
#include "FlashIndicationWrapper.h"
#include "FlashRequestProxy.h"

//#include "testmemcpy2.h"

#ifndef BSIM
#define BUFFER_COUNT 128
#else
#define BUFFER_COUNT 8
#endif

sem_t done_sem;
int srcAlloc;
int dstAlloc;
unsigned int *srcBuffer = 0;
unsigned int *dstBuffer = 0;
#ifndef BSIM
int numWords = 16 << 18;
#else
int numWords = 128 << 10;
#endif
bool finished = false;
bool memcmp_fail = false;
unsigned int memcmp_count = 0;

int srcAllocs[BUFFER_COUNT];
int dstAllocs[BUFFER_COUNT];
unsigned int ref_srcAllocs[BUFFER_COUNT];
unsigned int ref_dstAllocs[BUFFER_COUNT];
unsigned int* srcBuffers[BUFFER_COUNT];
unsigned int* dstBuffers[BUFFER_COUNT];

int numBytes = 2 << (10+3); // 8KB buffer
size_t alloc_sz = numBytes*sizeof(unsigned char);


void dump(const char *prefix, char *buf, size_t len)
{
    fprintf(stderr, "%s ", prefix);
    for (int i = 0; i < len ; i++) {
	fprintf(stderr, "%02x", (unsigned char)buf[i]);
	if (i % 32 == 31)
	  fprintf(stderr, "\n");
    }
    fprintf(stderr, "\n");
}

class FlashIndication : public FlashIndicationWrapper
{

public:
  FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

  virtual void writeDone(unsigned int tag) {
    fprintf(stderr, "write done tag: %d\n", tag);
    if ( tag == 1 ) sem_post(&done_sem);
  }
  virtual void readDone(unsigned int tag) {
    if ( tag == 1 ) sem_post(&done_sem);
    fprintf(stderr, "read done tag: %d\n", tag);
    //finished = true;
    //memcmp_fail = memcmp(srcBuffer, dstBuffer, numWords*sizeof(unsigned int));
  }
  virtual void hexDump(unsigned int data) {
  	printf( "%x--\n", data );
	fflush(stdout);
  }
};

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

	srcAlloc = portalAlloc(alloc_sz);
	dstAlloc = portalAlloc(alloc_sz);
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

		device->addReadHostBuffer(ref_dstAllocs[i], i);
		device->addWriteHostBuffer(ref_srcAllocs[i], i);
	}

	srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, alloc_sz);


	portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
	portalDCacheFlushInval(dstAlloc, alloc_sz, dstBuffer);
	fprintf(stderr, "Main::flush and invalidate complete\n");

	for ( int i = 0; i < 8192/4; i++ ) {
		for ( int j = 0; j < BUFFER_COUNT; j++ ) {
			dstBuffers[j][i] = 0;
			srcBuffers[j][i] = i;
		}
	}

	device->writePage(0,0,0,0,0);
	device->writePage(0,0,0,1,1);
	sem_wait(&done_sem);
	printf( "wrote pages to flash!\n" );
  
	for ( int i = 0; i < 32; i++ ) {
		device->sendTest(i);
		//device->readPage(0,0,0,i,i);
	}
	printf( "sent test data to aurora!\n" );
	device->readPage(0,0,0,0,0);
	device->readPage(0,0,0,1,1);
	printf( "trying reading from page!\n" );

	sem_wait(&done_sem);
	
	for ( int i = 0; i < 8192/4; i++ ) {
		printf( "0 %d\n", dstBuffers[0][i] );
		printf( "1 %d\n", dstBuffers[1][i] );
	}

	//runtest(argc, argv);
	while(1) sleep(1);

	exit(memcmp_fail);
}
