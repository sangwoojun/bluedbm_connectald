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

//#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "FlashIndication.h"
#include "FlashRequest.h"

#include "flash.h"


//-----------------------------------------------------
//DEFINITION of global vars (some default initialized)
//-----------------------------------------------------
int g_debuglevel = 5; //default
bool g_testpass = true;
bool g_checkdata = true;
unsigned int* readBuffers[NUM_TAGS];
unsigned int* writeBuffers[NUM_TAGS];
FlashRequestProxy *device;


//extern FlashRequestProxy *g_device;

int myid;

//---------------------------------------------
//Local erase, read, write, read test
//---------------------------------------------
void local_test(bool check, int read_repeat, int debug_lvl ) {
	LOG(0, "LOG: starting local_test...\n");
	g_checkdata = check;
	g_debuglevel = debug_lvl;
	g_testpass = true;
	int node = myid;

	timespec start, now;
	double timeElapsed = 0; 
	double bw = 0;
	//erase all blocks
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				eraseBlock(node, bus, chip, blk, waitIdleEraseTag());
			}
		}
	}

	while (true) {
		if ( getNumErasesInFlight() == 0 ) break;
	}

	//read back erased pages
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				int page = 0;
				readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
			}
		}
	}

	while (true) {
		if ( getNumReadsInFlight() == 0 ) break;
	}


	int pagesWritten = 0;
	clock_gettime(CLOCK_REALTIME, & start);
	//write pages
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				int page = 0;
				int freeTag = waitIdleWriteBuffer();
				if (g_checkdata) {
					//fill write memory only if we're doing readback checks
					for (unsigned int w=0; w<PAGE_SIZE/sizeof(unsigned int); w++) {
						writeBuffers[freeTag][w] = hashAddrToData(node, bus, chip, blk, w);
					}
				}
				//send request
				writePage(node, bus, chip, blk, page, freeTag); 
				pagesWritten++;
			}
		}
	}
	while (true) {
		if ( getNumWritesInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	timeElapsed = timespec_diff_sec(start, now);
	bw = (pagesWritten*8)/timeElapsed/1024; //MB/s
	//double latency = timeElapsed/pagesWritten;
	//double latency_us = latency*1000000;
	LOG(0, "LOG: finished writing to page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
							timeElapsed, pagesWritten, bw);


	int pagesRead = 0;
	clock_gettime(CLOCK_REALTIME, & start);
	for (int rep = 0; rep < read_repeat; rep++) {
		for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
			for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
				for (int bus = 0; bus < NUM_BUSES; bus++){
					int page = 0;
					readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
					pagesRead++;
				}
			}
		}
	}
	while (true) {
		if ( getNumReadsInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	timeElapsed = timespec_diff_sec(start, now);
	bw = (pagesRead*8)/timeElapsed/1024; //MB/s

	LOG(0, "LOG: reading from page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
							timeElapsed, pagesRead, bw);

	device->debugDumpReq(0);
	sleep(1);

	for ( int t = 0; t < NUM_TAGS; t++ ) {
		for ( unsigned int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			LOG(1, "%x %x %x\n", t, i, readBuffers[t][i] );
		}
	}

	if (g_checkdata) {
		if (g_testpass) {
			LOG(0, "LOG: local_test passed!\n");
		}
		else {
			LOG(0, "LOG: **ERROR: local_test FAILED!\n");
		}
	} else {
			LOG(0, "LOG: local_test complete. No checks done\n");
	}
}





//---------------------------------------------------
//One node accessing multiple flash boards 
//erase, read, write, read test
//---------------------------------------------------
void one_to_many_test(bool check, int read_repeat, int debug_lvl, int accessNode) {
	LOG(0, "LOG: starting one_to_many_test...\n");
	if (myid!=accessNode) {
		LOG(0, "[%d] LOG: sleeping indefinitely...\n", myid);
		while (true) {
			device->debugDumpReq(0);
			sleep(1);
		}
	}

	g_checkdata = check;
	g_debuglevel = debug_lvl;
	g_testpass = true;

	timespec start, now;
	double timeElapsed = 0; 
	double bw = 0;
	//erase all blocks
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				for (int node = 0; node < NUM_NODES; node++) {
					eraseBlock(node, bus, chip, blk, waitIdleEraseTag());
				}
			}
		}
	}

	while (true) {
		if ( getNumErasesInFlight() == 0 ) break;
	}

	//read back erased pages
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				for (int node = 0; node < NUM_NODES; node++) {
					int page = 0;
					readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
				}
			}
		}
	}

	while (true) {
		if ( getNumReadsInFlight() == 0 ) break;
	}


	int pagesWritten = 0;
	clock_gettime(CLOCK_REALTIME, & start);
	//write pages
	for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
		for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
			for (int bus = 0; bus < NUM_BUSES; bus++){
				for (int node = 0; node < NUM_NODES; node++) {
					int page = 0;
					int freeTag = waitIdleWriteBuffer();
					if (g_checkdata) {
						//fill write memory only if we're doing readback checks
						for (unsigned int w=0; w<PAGE_SIZE/sizeof(unsigned int); w++) {
							writeBuffers[freeTag][w] = hashAddrToData(node, bus, chip, blk, w);
						}
					}
					//send request
					writePage(node, bus, chip, blk, page, freeTag); 
					pagesWritten++;
				}
			}
		}
	}
	while (true) {
		if ( getNumWritesInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	timeElapsed = timespec_diff_sec(start, now);
	bw = (pagesWritten*8)/timeElapsed/1024; //MB/s
	//double latency = timeElapsed/pagesWritten;
	//double latency_us = latency*1000000;
	LOG(0, "LOG: finished writing to page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
			timeElapsed, pagesWritten, bw);


	int pagesRead = 0;
	clock_gettime(CLOCK_REALTIME, & start);
	for (int rep = 0; rep < read_repeat; rep++) {
		for (int blk = 0; blk < BLOCKS_PER_CHIP; blk++){
			for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
				for (int bus = 0; bus < NUM_BUSES; bus++){
					for (int node = 0; node < NUM_NODES; node++) {
						int page = 0;
						readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
						pagesRead++;
					}
				}
			}
		}
	}
	while (true) {
		if ( getNumReadsInFlight() == 0 ) break;
	}
	clock_gettime(CLOCK_REALTIME, & now);
	timeElapsed = timespec_diff_sec(start, now);
	bw = (pagesRead*8)/timeElapsed/1024; //MB/s

	LOG(0, "LOG: finished reading from page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
			timeElapsed, pagesRead, bw);

	device->debugDumpReq(0);
	sleep(1);

	for ( int t = 0; t < NUM_TAGS; t++ ) {
		for ( unsigned int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			LOG(1, "%x %x %x\n", t, i, readBuffers[t][i] );
		}
	}

	if (g_checkdata) {
		if (g_testpass) {
			LOG(0, "LOG: one_to_many_test passed!\n");
		}
		else {
			LOG(0, "LOG: **ERROR: one_to_many_test FAILED!\n");
		}
	} else {
		LOG(0, "LOG: one_to_many_test complete. No checks done\n");
	}
}



//---------------------------------------------------
//Multi-access: multiple node accessing multiple boards 
//erase, read, write, read test
//to avoid conflicts, each node writes to a diff block of a chip
// Warning: do not increase test_repeat too many times.. it wears out the flash
//---------------------------------------------------
void many_to_many_test(bool check, int test_repeat, int read_repeat, int debug_lvl) {
	if (test_repeat > 10) {
		LOG(0, "LOG: **ERROR:  Please reduce # tests to protect flash. Aborting\n");
		return;
	} else if (test_repeat<1 || read_repeat<1) {
		LOG(0, "LOG: **ERROR:  repeat numbers <1. Aborting\n");
	}


	LOG(0, "LOG: starting many_to_many_test...\n");
	g_checkdata = check;
	g_debuglevel = debug_lvl;
	g_testpass = true;

	timespec start, now;
	double timeElapsed = 0; 
	double bw = 0;

	for (int ti = 0; ti<test_repeat; ti++) {
		//erase all blocks
		for (int blk = myid; blk < BLOCKS_PER_CHIP; blk+=NUM_NODES){ //each node a diff blk
			for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
				for (int bus = 0; bus < NUM_BUSES; bus++){
					for (int node = 0; node < NUM_NODES; node++) {
						eraseBlock(node, bus, chip, blk, waitIdleEraseTag());
					}
				}
			}
		}

		while (true) {
			if ( getNumErasesInFlight() == 0 ) break;
		}

		//read back erased pages
		for (int blk = myid; blk < BLOCKS_PER_CHIP; blk+=NUM_NODES){
			for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
				for (int bus = 0; bus < NUM_BUSES; bus++){
					for (int node = 0; node < NUM_NODES; node++) {
						int page = 0;
						readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
					}
				}
			}
		}

		while (true) {
			if ( getNumReadsInFlight() == 0 ) break;
		}

		int pagesWritten = 0;
		clock_gettime(CLOCK_REALTIME, & start);
		//write pages
		for (int blk = myid; blk < BLOCKS_PER_CHIP; blk+=NUM_NODES){
			for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
				for (int bus = 0; bus < NUM_BUSES; bus++){
					for (int node = 0; node < NUM_NODES; node++) {
						int page = 0;
						int freeTag = waitIdleWriteBuffer();
						if (g_checkdata) {
							//fill write memory only if we're doing readback checks
							for (unsigned int w=0; w<PAGE_SIZE/sizeof(unsigned int); w++) {
								writeBuffers[freeTag][w] = hashAddrToData(node, bus, chip, blk, w);
							}
						}
						//send request
						writePage(node, bus, chip, blk, page, freeTag); 
						pagesWritten++;
					}
				}
			}
		}
		while (true) {
			if ( getNumWritesInFlight() == 0 ) break;
		}
		clock_gettime(CLOCK_REALTIME, & now);
		timeElapsed = timespec_diff_sec(start, now);
		bw = (pagesWritten*8)/timeElapsed/1024; //MB/s
		//double latency = timeElapsed/pagesWritten;
		//double latency_us = latency*1000000;
		LOG(0, "LOG: finished writing to page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
				timeElapsed, pagesWritten, bw);


		int pagesRead = 0;
		clock_gettime(CLOCK_REALTIME, & start);
		for (int rep = 0; rep < read_repeat; rep++) {
			for (int blk = myid; blk < BLOCKS_PER_CHIP; blk+=NUM_NODES){
				for (int chip = 0; chip < CHIPS_PER_BUS; chip++){
					for (int bus = 0; bus < NUM_BUSES; bus++){
						for (int node = 0; node < NUM_NODES; node++) {
							int page = 0;
							readPage(node, bus, chip, blk, page, waitIdleReadBuffer());
							pagesRead++;
						}
					}
				}
			}
		}
		while (true) {
			if ( getNumReadsInFlight() == 0 ) break;
		}
		clock_gettime(CLOCK_REALTIME, & now);
		timeElapsed = timespec_diff_sec(start, now);
		bw = (pagesRead*8)/timeElapsed/1024; //MB/s

		LOG(0, "LOG: finished reading from page. Time=%f, NumPages=%d, BW=%f MB/s\n", 
				timeElapsed, pagesRead, bw);

	} //for test repeat

	device->debugDumpReq(0);
	sleep(1);

	for ( int t = 0; t < NUM_TAGS; t++ ) {
		for ( unsigned int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			LOG(1, "%x %x %x\n", t, i, readBuffers[t][i] );
		}
	}

	if (g_checkdata) {
		if (g_testpass) {
			LOG(0, "LOG: many_to_many_test passed!\n");
		}
		else {
			LOG(0, "LOG: **ERROR: many_to_many_test FAILED!\n");
		}
	} else {
		LOG(0, "LOG: many_to_many_test complete. No checks done\n");
	}
}



int main(int argc, const char **argv)
{

	//Getting my ID
	char hostname[32];
	gethostname(hostname,32);

	char* userhostid = getenv("BDBM_ID");
	if ( userhostid != NULL ) {
		myid = atoi(userhostid);
	} else {
		myid = atoi(hostname+strlen("bdbm"));
		if ( strstr(hostname, "bdbm") == NULL ) {
			myid = 1;
		}
	}

	fprintf(stderr, "Main: myid=%d\n", myid);

	init_dma();


	//Start ext aurora
	auroraifc_start(myid);

	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	device->debugDumpReq(0);
	sleep(1);
	device->debugDumpReq(0);
	sleep(1);

	//void local_test(bool check, int read_repeat, int debug_lvl )
	local_test(true, 1, 5);
	LOG(0, "Press any key to continue..\n");
	//gets(str);

	/*
	//void one_to_many_test(bool check, int read_repeat, int debug_lvl, int accessNode)
	one_to_many_test(true, 1, 5, 1);
	LOG(0, "Press any key to continue..\n");
	gets(str);
	*/

	
	//void many_to_many_test(bool check, int test_repeat, int read_repeat, int debug_lvl)
	many_to_many_test(true, 1, 10, 5);


}





