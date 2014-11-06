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


int main(int argc, const char **argv)
{

	DmaDebugRequestProxy *hostDmaDebugRequest = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
	MMUConfigRequestProxy *dmap = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
	DmaManager *dma = new DmaManager(hostDmaDebugRequest, dmap);
	DmaDebugIndication *hostDmaDebugIndication = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
	MMUConfigIndication *hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);


	fprintf(stderr, "Main::allocating memory...\n");
	
	flashifc_init();

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	portalExec_start();
	printf( "Done portalExec_start\n" ); fflush(stdout);

	flashifc_alloc(dma);
	
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
			readBuffers[j][i] = 0;
		}
	}

	printf ( "sending start msg\n" ); fflush(stdout);

	flashifc_start(/*datasource*/1);

	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);

	for (int repeat = 0; repeat < 1000000; repeat++){
	//for (int blk = 0; blk < 1; blk++){
		//for (int chip = 7; chip >= 0; chip--){
			//for (int bus = 7; bus >= 0; bus--){
				//int blk = 0;

				//random testing
				int blk = rand() % 1024;
				int chip = rand() % 8;
				int bus = rand() % 8;

				int page = 0;
				readPage(bus, chip, blk, page, waitIdleReadBuffer());
				//fprintf(stderr, "rd pg %d %d %d %d\n", bus, chip, blk, page);

				/*
				printf("press enter to continue:\n");
				char enter = 0;
				while (enter != '\r' && enter != '\n') { enter = getchar(); }
				
				for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
					for ( int i = 0; i < (8192+64)/4; i++ ) {
						//if ( i > (8192+64)/4 - 2 )
					 fprintf(stderr,  "%x %x %x\n", j, i, readBuffers[j][i] );
					}
				}

				enter = 0;
				printf("press enter to continue:\n");
				while (enter != '\r' && enter != '\n') { enter = getchar(); }
				*/
				
	//		}
	//	}
	//}
	}
	



	printf( "trying reading from page!\n" );

	while (true) {
		usleep(100);
		if ( getNumReadsInFlight() == 0 ) break;
	}

	clock_gettime(CLOCK_REALTIME, & now);
	printf( "finished reading from page! %f\n", timespec_diff_sec(start, now) );

	for ( int j = 0; j < READ_BUFFER_COUNT; j++ ) {
		for ( int i = 0; i < (8192+64)/4; i++ ) {
			//if ( i > (8192+64)/4 - 2 )
		 fprintf(stderr,  "%x %x %x\n", j, i, readBuffers[j][i] );
		}
	}

	exit(0);
}
