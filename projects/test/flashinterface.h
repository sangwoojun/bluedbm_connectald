#ifndef __FLASH_INTERFACE_H__
#define __FLASH_INTERFACE_H__

#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <semaphore.h>

#include "connectal.h"

#define TEST_DMA_CHANNELS 4

#ifndef BSIM
	#define DMA_BUFFER_COUNT 4
	#define LARGE_NUMBER (1024*1024/8)
#else
	#define DMA_BUFFER_COUNT 4
	#define LARGE_NUMBER 512
#endif

#define READ_BUFFER_WAYS (128/DMA_BUFFER_COUNT)
#define WRITE_BUFFER_WAYS (64/DMA_BUFFER_COUNT)
#define READ_BUFFER_COUNT (DMA_BUFFER_COUNT*READ_BUFFER_WAYS)
#define WRITE_BUFFER_COUNT (DMA_BUFFER_COUNT*WRITE_BUFFER_WAYS)

extern bool verbose;

extern char* log_prefix;

extern unsigned int* writeBuffers[WRITE_BUFFER_COUNT];
extern unsigned int* readBuffers[READ_BUFFER_COUNT];

extern bool srcBufferBusy[WRITE_BUFFER_COUNT];
extern bool dstBufferBusy[WRITE_BUFFER_COUNT];

extern int curWritesInFlight;
extern int curReadsInFlight;

extern pthread_mutex_t flashReqMutex;
extern pthread_cond_t flashReqCond;
extern pthread_mutex_t cmdReqMutex;
extern pthread_cond_t cmdReqCond;

extern int curCmdCountBudget;

extern sem_t wait_sem;

double timespec_diff_sec( timespec start, timespec end );

class FlashIndication : public FlashIndicationWrapper
{

public:
  FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

  virtual void writeDone(unsigned int bufidx) {
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight --;

	if ( srcBufferBusy[bufidx] == false ) {
		fprintf(stderr, "EXCEPTION: received unused buffer write done %d\n", bufidx);
	}


	srcBufferBusy[bufidx] = false;
	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);
	
	if ( curWritesInFlight < 0 ) {
		curWritesInFlight = 0;
		fprintf(stderr, "Write requests in flight cannot be negative\n" );
	}


	if ( verbose ) printf( "%s received write done buffer: %d curWritesInFlight: %d\n", log_prefix, bufidx, curWritesInFlight );
	//sem_post(&wait_sem);

  }
  virtual void readDone(unsigned int rbuf) {

	if ( verbose ) {
		printf( "%s received read page buffer: %d %d\n", log_prefix, rbuf, curReadsInFlight );
		fflush(stdout);
	}

	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight --;
	if ( dstBufferBusy[rbuf] == false ) {
		fprintf(stderr, "EXCEPTION: received unused buffer read done %d\n", rbuf);
	}
	dstBufferBusy[rbuf] = false;

	pthread_cond_broadcast(&flashReqCond);
	pthread_mutex_unlock(&flashReqMutex);

	if ( curReadsInFlight < 0 ) {
		fprintf(stderr, "Read requests in flight cannot be negative %d\n", curReadsInFlight );
		curReadsInFlight = 0;
	}

	if ( verbose ) {
		int busycount = 0;
		for ( int i = 0; i < READ_BUFFER_COUNT; i++ ) {
			if ( dstBufferBusy[i] == true ) busycount++;
		}
		printf( "%s Finished pagedone: buffer: %d %d %d\n", log_prefix,  rbuf, curReadsInFlight, busycount );
		fflush(stdout);
	}
  }

  virtual void reqFlashCmd(unsigned int inQ, unsigned int count) {
	if ( verbose ) {
		printf( "\t%s increase flash cmd budget: %d (%d)\n", log_prefix, curCmdCountBudget, inQ );
		fflush(stdout);
	}
	pthread_mutex_lock(&cmdReqMutex);
	curCmdCountBudget += count;
	pthread_cond_broadcast(&cmdReqCond);
	pthread_mutex_unlock(&cmdReqMutex);
	if ( verbose ) {
		printf( "\t%s finished increase flash cmd budget: %d (%d)\n", log_prefix, curCmdCountBudget, inQ );
		fflush(stdout);
	}

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


///////////// Flash Interface Functions //////////////////////

int getNumWritesInFlight();
int getNumReadsInFlight();

void writePage(int channel, int chip, int block, int page, int bufidx);
int readPage(int channel, int chip, int block, int page, int bufidx);

int getIdleWriteBuffer(int channel);
int waitIdleWriteBuffer(int channel);
int getIdleReadBuffer();
int waitIdleReadBuffer();

void flashifc_init();
void flashifc_alloc(DmaManager* dma);
void flashifc_start(int datasource);

#endif
