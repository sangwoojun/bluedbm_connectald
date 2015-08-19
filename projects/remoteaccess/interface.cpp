#include "interface.h"

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>   

#ifndef BSIM
	bool verbose = false;
#else
	bool verbose = true;
#endif

sem_t wait_sem;

int srcAllocs[DMA_BUFFER_COUNT];
int dstAllocs[DMA_BUFFER_COUNT];
unsigned int ref_srcAllocs[DMA_BUFFER_COUNT];
unsigned int ref_dstAllocs[DMA_BUFFER_COUNT];
unsigned int* srcBuffers[DMA_BUFFER_COUNT];
unsigned int* dstBuffers[DMA_BUFFER_COUNT];

unsigned int* writeBuffers[WRITE_BUFFER_COUNT];
unsigned int* readBuffers[READ_BUFFER_COUNT];

pthread_mutex_t flashReqMutex;
pthread_cond_t flashReqCond;

int rnumBytes = (1 << (10 +4))*READ_BUFFER_WAYS; //16KB buffer, to be safe
int wnumBytes = (1 << (10 +4))*WRITE_BUFFER_WAYS; //16KB buffer, to be safe
size_t ralloc_sz = rnumBytes*sizeof(unsigned char);
size_t walloc_sz = wnumBytes*sizeof(unsigned char);

const char* log_prefix = "\t\tLOG: ";

GeneralRequestProxy *device = 0;
GeneralIndication *deviceIndication = 0;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}


void interface_init() {
	device = new GeneralRequestProxy(GeneralRequestPortal);
	deviceIndication = new GeneralIndication(GeneralIndicationPortal);
	
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		srcAllocs[i] = portalAlloc(walloc_sz, 1);
		dstAllocs[i] = portalAlloc(ralloc_sz, 1);
		srcBuffers[i] = (unsigned int *)portalMmap(srcAllocs[i], walloc_sz);
		dstBuffers[i] = (unsigned int *)portalMmap(dstAllocs[i], ralloc_sz);
	}
	
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashReqCond, NULL);
}

void interface_alloc(DmaManager* dma) {
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		portalCacheFlush(srcAllocs[i], srcBuffers[i], walloc_sz, 1);
		portalCacheFlush(dstAllocs[i], dstBuffers[i], ralloc_sz, 1);
		ref_srcAllocs[i] = dma->reference(srcAllocs[i]);
		ref_dstAllocs[i] = dma->reference(dstAllocs[i]);
	}
	
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < WRITE_BUFFER_WAYS; j++ ) {
			int idx = i*WRITE_BUFFER_WAYS+j;

			int offset = j*1024*16;
//			device->addWriteHostBuffer(ref_srcAllocs[i], offset, idx);
			writeBuffers[idx] = srcBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < READ_BUFFER_WAYS; j++ ) {
			int idx = i*READ_BUFFER_WAYS+j;

			int offset = j*1024*16;
//			device->addReadHostBuffer(ref_dstAllocs[i], offset, idx);
			readBuffers[idx] = dstBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
}

void setAuroraRouting2(int myid, int src, int dst, int port1, int port2) {
	if ( myid != src ) return;

	for ( int i = 0; i < 8; i ++ ) {
		if ( i % 2 == 0 ) { 
			device->setAuroraExtRoutingTable(dst,port1, i);
		} else {
			device->setAuroraExtRoutingTable(dst,port2, i);
		}
	}
}

void auroraifc_start(int myid) {
	device->setNetId(myid);
	device->auroraStatus(0);

	//This is not strictly required
	for ( int i = 0; i < 8; i++ ) 
		device->setAuroraExtRoutingTable(myid,0,i);

	// This is set up such that all nodes can one day 
	// read the same routing file and apply it
	setAuroraRouting2(myid, 0,1, 0,2);
	setAuroraRouting2(myid, 0,2, 1,3);
	setAuroraRouting2(myid, 0,3, 1,3);

	setAuroraRouting2(myid, 1,0, 0,1);
	setAuroraRouting2(myid, 1,2, 0,1);
	setAuroraRouting2(myid, 1,3, 0,1);
	
	setAuroraRouting2(myid, 2,0, 0,3);
	setAuroraRouting2(myid, 2,1, 0,3);
	setAuroraRouting2(myid, 2,3, 0,3);

	setAuroraRouting2(myid, 3,0, 1,2);
	setAuroraRouting2(myid, 3,1, 1,2);
	setAuroraRouting2(myid, 3,2, 0,3);

	usleep(100);
}


int srcfd = 0;
uint64_t* data64 = NULL;
int size = 1024*1024*1024;
void generalifc_start(int datasource) {
	device->start(datasource);
	/*
	srcfd = open("/home/wjun/large.dat", O_RDONLY);
	void* data = mmap(NULL, size, PROT_READ, MAP_PRIVATE, srcfd, 0);
	data64 = (uint64_t*) data;
	*/
}

void generalifc_readRemotePage(int myid) {
/*
	int src = 0;
	int dst = 1;
	if ( myid != src ) return;
*/
	if ( myid == 5 ) { 
		device->sendData(1024*1024*1024, 6, 0);
	} else if ( myid == 6 ) { 
		device->sendData(1024*1024*1024, 5, 0);
	} else if ( myid == 7 ) {
		device->sendData(1024*1024*1024, 6, 0);
	} else {
		device->sendData(1024*1024*1024, 5, 0);
	}
	printf( "Sent read requests\n" ); fflush(stdout);

/*
	for ( int i = 0; i < 2; i++ ) {
		clock_gettime(CLOCK_REALTIME, & deviceIndication->aurorastart);
		// addr, targetnode, datasource, tag
		//device->readRemotePage(i, dst, 1, 0);
		usleep(10000);
	}
*/
}
void generalifc_latencyReport() {
	for ( int i = 0; i < 16; i++ ) {
		float tot = deviceIndication->timediff[i];
		float avg = tot/deviceIndication->timediffcnt[i];
		printf( "%d: %f\n",i,avg );
	}
}

void GeneralIndication::readPage(uint64_t addr, uint32_t dstnode, uint32_t datasource) {
	printf( "readpage req! -> %d\n", dstnode ); fflush(stdout);
	//device->readPageDone(0);
	if ( datasource == 1 ) {
		memcpy(data64+(addr*8192/sizeof(uint64_t)), srcBuffers[0], 8192);
	}

	if ( datasource < 3 ) {
		//device->sendDMAPage(ref_srcAllocs[0], dstnode);
	} else {
		//device->readPageDone(0);
	}
}

