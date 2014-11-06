#include "flashinterface.h"

#ifndef BSIM
	bool verbose = true;
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
bool srcBufferBusy[WRITE_BUFFER_COUNT];
bool dstBufferBusy[WRITE_BUFFER_COUNT];

unsigned int* writeBuffers[WRITE_BUFFER_COUNT];
unsigned int* readBuffers[READ_BUFFER_COUNT];

int curWritesInFlight = 0;
int curReadsInFlight = 0;

pthread_mutex_t flashReqMutex;
pthread_cond_t flashReqCond;
pthread_mutex_t cmdReqMutex;
pthread_cond_t cmdReqCond;

int curCmdCountBudget = 0;

int rnumBytes = (1 << (10 +4))*READ_BUFFER_WAYS; //16KB buffer, to be safe
int wnumBytes = (1 << (10 +4))*WRITE_BUFFER_WAYS; //16KB buffer, to be safe
size_t ralloc_sz = rnumBytes*sizeof(unsigned char);
size_t walloc_sz = wnumBytes*sizeof(unsigned char);

int getNumWritesInFlight() { return curWritesInFlight; }
int getNumReadsInFlight() { return curReadsInFlight; }

char* log_prefix = "\t\tLOG: ";

FlashRequestProxy *device = 0;
FlashIndication *deviceIndication = 0;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}


void writePage(int channel, int chip, int block, int page, int bufidx) {
	if ( bufidx > WRITE_BUFFER_COUNT ) return;

	if ( verbose ) { printf( "%s requesting write page\n", log_prefix ); fflush(stdout); }


	pthread_mutex_lock(&cmdReqMutex);
	while (curCmdCountBudget <= 0) {
		//noCmdBudgetCount++;
		if ( verbose ) { printf( "%s no cmd budget \n", log_prefix ); fflush(stdout);}
		pthread_cond_wait(&cmdReqCond, &cmdReqMutex);
	}
	curCmdCountBudget--; 
	pthread_mutex_unlock(&cmdReqMutex);


	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) { printf( "%s sending write req to device %d\n", log_prefix, curWritesInFlight ); fflush(stdout); }
	device->writePage(channel,chip,block,page,bufidx);

}

int getIdleWriteBuffer(int channel) {
	pthread_mutex_lock(&flashReqMutex);

	int ret = -1;
	for ( int i = WRITE_BUFFER_WAYS*channel
		; i < WRITE_BUFFER_WAYS*(channel+1)
		; i++ ) {

		if ( !srcBufferBusy[i] ) {
			srcBufferBusy[i] = true;
			ret = i;
			break;
		}
	}
	pthread_mutex_unlock(&flashReqMutex);
	return ret;
}

int waitIdleWriteBuffer(int channel) {
	int bufidx = getIdleWriteBuffer(channel);
	while (bufidx < 0 ) {
		pthread_mutex_lock(&flashReqMutex);
		pthread_cond_wait(&flashReqCond, &flashReqMutex);
		pthread_mutex_unlock(&flashReqMutex);

		bufidx = getIdleWriteBuffer(channel);
	}

	if ( verbose ) printf( "%s idle write buffer discovered %d @ channel %d\n", log_prefix, bufidx, channel );

	return bufidx;
}

int getIdleReadBuffer() {
	pthread_mutex_lock(&flashReqMutex);
	int ret = -1;
	for ( int i = 0; i < READ_BUFFER_COUNT; i++ ) {
		if ( !dstBufferBusy[i] ) {
			dstBufferBusy[i] = true;
			ret = i;
			break;
		}
	}
	pthread_mutex_unlock(&flashReqMutex);
	return ret;
}

int waitIdleReadBuffer() {
	int bufidx = getIdleReadBuffer();

	while ( bufidx < 0 ) {
		pthread_mutex_lock(&flashReqMutex);
		pthread_cond_wait(&flashReqCond, &flashReqMutex);
		pthread_mutex_unlock(&flashReqMutex);

		bufidx = getIdleReadBuffer();
	}

	return bufidx;
}


int readPage(int channel, int chip, int block, int page, int bufidx) {

	// track read access latency for debuf
	//clock_gettime(CLOCK_REALTIME, & readstart[readstartidx]);
	//readstartidx++;
	//if ( readstartidx >= TAG_COUNT ) readstartidx = 0;

	// check if hw can accept requests
	pthread_mutex_lock(&cmdReqMutex);
	while (curCmdCountBudget <= 0) {
		//noCmdBudgetCount++;
		if ( verbose ) printf( "%s no cmd budget \n", log_prefix );
		pthread_cond_wait(&cmdReqCond, &cmdReqMutex);
	}
	curCmdCountBudget --;
	pthread_mutex_unlock(&cmdReqMutex);

	//curReqsInFlight ++;
	
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "%s sending read page request with buffer=%d @%d %d %d %d\n", log_prefix, bufidx, channel, chip, block, page );
	device->readPage(channel,chip,block,page,bufidx);
	return bufidx;
}

void flashifc_init() {
	device = new FlashRequestProxy(IfcNames_FlashRequest);
	deviceIndication = new FlashIndication(IfcNames_FlashIndication);
	
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		srcAllocs[i] = portalAlloc(walloc_sz);
		dstAllocs[i] = portalAlloc(ralloc_sz);
		srcBuffers[i] = (unsigned int *)portalMmap(srcAllocs[i], walloc_sz);
		dstBuffers[i] = (unsigned int *)portalMmap(dstAllocs[i], ralloc_sz);
		fprintf(stderr, "dstAlloc[%d] = %x\n", i, dstAllocs[i]); 
	}
	
	curWritesInFlight = 0;
	curCmdCountBudget = 0;
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_mutex_init(&cmdReqMutex, NULL);
	pthread_cond_init(&flashReqCond, NULL);
	pthread_cond_init(&cmdReqCond, NULL);
}

void flashifc_alloc(DmaManager* dma) {
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		portalDCacheFlushInval(srcAllocs[i], walloc_sz, srcBuffers[i]);
		portalDCacheFlushInval(dstAllocs[i], ralloc_sz, dstBuffers[i]);
		ref_srcAllocs[i] = dma->reference(srcAllocs[i]);
		ref_dstAllocs[i] = dma->reference(dstAllocs[i]);
	}
	
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < WRITE_BUFFER_WAYS; j++ ) {
			int idx = i*WRITE_BUFFER_WAYS+j;
			srcBufferBusy[idx] = false;

			int offset = j*1024*16;
			device->addWriteHostBuffer(ref_srcAllocs[i], offset, idx);
			fprintf(stderr, "DEBUG: ref_srcAllocs[%d] = %x; offset=%d\n", i, ref_srcAllocs[i], offset);
			writeBuffers[idx] = srcBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
	for ( int i = 0; i < DMA_BUFFER_COUNT; i++ ) {
		for ( int j = 0; j < READ_BUFFER_WAYS; j++ ) {
			int idx = i*READ_BUFFER_WAYS+j;
			dstBufferBusy[idx] = false;

			int offset = j*1024*16;
			device->addReadHostBuffer(ref_dstAllocs[i], offset, idx);
			fprintf(stderr, "DEBUG: ref_dstAllocs[%d] = %x;  offset=%d\n", i, ref_dstAllocs[i], offset);
			readBuffers[idx] = dstBuffers[i] + (offset/sizeof(unsigned int));
		}
	}
}

void flashifc_start(int datasource) {
	device->start(datasource);
	
	clock_gettime(CLOCK_REALTIME, & deviceIndication->aurorastart);
	printf( "sending aurora test req\n" ); fflush(stdout);
}
