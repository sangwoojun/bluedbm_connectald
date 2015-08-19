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
#include "interface.h"

int main(int argc, const char **argv)
{
	char hostname[32];
	gethostname(hostname,32);

	//FIXME "lightning" is evaluated to 0,
	// so when bdbm00 is returned to the cluster,
	// code needs to be modified
	/*
	if ( strstr(hostname, "bdbm") == NULL 
		&& strstr(hostname, "umma") == NULL
		&& strstr(hostname, "lightning") == NULL ) {
		
		fprintf(stderr, "ERROR: hostname should be bdbm[idx] or lightning\n");
		return 1;
	}
	*/


	unsigned long myid = strtoul(hostname+strlen("bdbm"), NULL, 0);
	if ( strstr(hostname, "bdbm") == NULL 
		&& strstr(hostname, "umma") == NULL
		&& strstr(hostname, "lightning") == NULL ) {
			
			myid = 0;

	}
	char* userhostid = getenv("BDBM_ID");
	if ( userhostid != NULL ) {
	  myid = strtoul(userhostid, NULL, 0);
	}

	MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(HostMemServerRequestPortal);
	MMURequestProxy *dmap = new MMURequestProxy(HostMMURequestPortal);
	DmaManager *dma = new DmaManager(dmap);
	MemServerIndication hostMemServerIndication(hostMemServerRequest, HostMemServerIndicationPortal);
	MMUIndication hostMMUIndication(dma, HostMMUIndicationPortal);


	fprintf(stderr, "Main::allocating memory...\n");
	
	interface_init();

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	interface_alloc(dma);
	
	printf( "Done allocating DMA buffers\n" ); fflush(stdout);

	printf( "initializing aurora with node id %ld\n", myid ); fflush(stdout);
	auroraifc_start(myid);

	/////////////////////////////////////////////////////////

	fprintf(stderr, "Main::flush and invalidate complete\n");
	if ( sem_init(&wait_sem, 1, 0) ) {
		//error
		fprintf(stderr, "sem_init failed!\n" );
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

	sleep(5);

	printf ( "sending start msg\n" ); fflush(stdout);
	generalifc_start(/*datasource*/1);
	//auroraifc_sendTest();

	generalifc_readRemotePage(myid);
	
	//sleep(2);
	//generalifc_latencyReport();

	printf( "Entering idle loop\n" );
	while(1) sleep(10);
	exit(0);
}
