#ifndef __GENERAL_INTERFACE_H__
#define __GENERAL_INTERFACE_H__

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
	#define LARGE_NUMBER 256
#endif

#define READ_BUFFER_WAYS (64/DMA_BUFFER_COUNT)
#define WRITE_BUFFER_WAYS (64/DMA_BUFFER_COUNT)
#define READ_BUFFER_COUNT (DMA_BUFFER_COUNT*READ_BUFFER_WAYS)
#define WRITE_BUFFER_COUNT (DMA_BUFFER_COUNT*WRITE_BUFFER_WAYS)

extern bool verbose;

extern const char* log_prefix;

extern unsigned int* writeBuffers[WRITE_BUFFER_COUNT];
extern unsigned int* readBuffers[READ_BUFFER_COUNT];

extern pthread_mutex_t flashReqMutex;
extern pthread_cond_t flashReqCond;

extern sem_t wait_sem;

double timespec_diff_sec( timespec start, timespec end );

class GeneralIndication : public GeneralIndicationWrapper
{

public:
	uint32_t timediff[16];
	uint32_t timediffcnt[16];
  GeneralIndication(unsigned int id) : GeneralIndicationWrapper(id){
  	for ( int i = 0; i < 16; i++ ) {
		timediff[i] = 0;
		timediffcnt[i] = 0;
	}
  }

  virtual void readPage(uint64_t addr,uint32_t dstnode, uint32_t datasource);
  virtual void recvSketch(uint32_t sketch, uint32_t latency) {
  	printf( "sketch: %x, latency: %d\n", sketch, latency );
	fflush(stdout);
  }

  timespec aurorastart;
  virtual void mismatch(unsigned int data, unsigned int data2) {
	printf( "diff %x--%d\n", data, data2 );
  }
  virtual void hexDump(unsigned int data) {
	printf( "%x--\n", data );
	timespec now;
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "aurora data! %f\n", timespec_diff_sec(aurorastart, now) );
	//fflush(stdout);
  }
  virtual void timeDiffDump(uint32_t diff, uint32_t ttype) {
  	if ( ttype < 16 ) {
		timediff[ttype] += diff;
		timediffcnt[ttype] ++;
	}
  }
};


///////////// General Interface Functions //////////////////////

void interface_init();
void interface_alloc(DmaManager* dma);
void generalifc_start(int datasource);
void generalifc_readRemotePage(int myid);
void generalifc_latencyReport();

void auroraifc_start(int myid);

void test_dram();

#endif
