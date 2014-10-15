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


#include "connectal.h"
#include "flashinterface.h"
#include "storagebridge.h"

void write_test() {
	timespec start, now;
	printf( "writing pages to flash!\n" ); fflush(stdout);
	clock_gettime(CLOCK_REALTIME, & start);
	//for ( int i = 0; i < 4; i++ ) {
	for ( int i = 0; i < LARGE_NUMBER/TEST_DMA_CHANNELS; i++ ) {
		for ( int j = 0; j < TEST_DMA_CHANNELS; j++ ) {
			if ( i % (1024*4) == 0 ) {
				printf( "writing page %d\n", i ); fflush(stdout);
			}
			writePage(j,0,0,i,waitIdleWriteBuffer(j));

			//sem_wait(&wait_sem);
		}
		//sleep(1);
	}
	printf( "waiting for writing pages to flash!\n" ); fflush(stdout);
	while ( getNumWritesInFlight() > 0 ) usleep(1000);
	clock_gettime(CLOCK_REALTIME, & now); fflush(stdout);
	printf( "finished writing to page! %f\n", timespec_diff_sec(start, now) );
	printf( "wrote pages to flash!\n" ); fflush(stdout);
}

void read_test() {
	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);
	//for ( int i = 0; i < 4; i++ ) {
	for ( int i = 0; i < LARGE_NUMBER/TEST_DMA_CHANNELS; i++ ) {
		for ( int j = 0; j < TEST_DMA_CHANNELS; j++ ) {

			if ( i % 1024 == 0 ) 
				printf( "reading page %d\n", i );

			readPage(j,0,0,i, waitIdleReadBuffer());
		}
	}

	printf( "trying reading from page!\n" );

	while (true) {
		usleep(100);
		if ( getNumReadsInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "finished reading from page! %f\n", timespec_diff_sec(start, now) );
}

int main(int argc, const char **argv)
{

	DmaDebugRequestProxy *hostDmaDebugRequest = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
	MMUConfigRequestProxy *dmap = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
	DmaManager *dma = new DmaManager(hostDmaDebugRequest, dmap);
	DmaDebugIndication *hostDmaDebugIndication = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
	MMUConfigIndication *hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);


	fprintf(stderr, "Main::allocating memory...\n");
	
	flashifc_init();
	storagebridge_init();

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	portalExec_start();
	printf( "Done portalExec_start\n" ); fflush(stdout);

	flashifc_alloc(dma);
	storagebridge_alloc(dma);
	
	printf( "Done allocating DMA buffers\n" ); fflush(stdout);


	/////////////////////////////////////////////////////////

	fprintf(stderr, "Main::flush and invalidate complete\n");
	if ( sem_init(&wait_sem, 1, 0) ) {
		//error
	}

	for ( int j = 0; j < WRITE_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			writeBuffers[j][i] = j;
		}
	}
	for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			readBuffers[j][i] = 8192/4-i;
		}
	}

	printf ( "sending start msg\n" ); fflush(stdout);

	flashifc_start();

	write_test();
	
	read_test();

	//for ( int j = 0; j < 5; j++ ) {
	for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			if ( i > (8192+64)/4 - 2 )
			printf( "%d %d %d\n", j, i, readBuffers[j][i] );
		}
	}

/*
	for ( int i = 0; i < READ_BUFFER_COUNT; i++ ) {
		printf( "buffer %d : %s\n", i, dstBufferBusy[i] ? "busy" : "idle" );
	}
	*/
	//printf( "Command buget was gone:%d \nTag was busy:%d\n", noCmdBudgetCount, noTagCount );

	exit(0);
}
