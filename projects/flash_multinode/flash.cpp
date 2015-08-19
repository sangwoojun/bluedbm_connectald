#include "flash.h"

//---------------------------------
//Shared vars for flash.h
//---------------------------------
volatile int curReadsInFlight = 0;
volatile int curWritesInFlight = 0;
volatile int curErasesInFlight = 0;
TagTableEntry readTagTable[NUM_TAGS]; 
TagTableEntry writeTagTable[NUM_TAGS]; 
TagTableEntry eraseTagTable[NUM_TAGS]; 
FlashStatusT flashStatus[NUM_NODES][NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];
pthread_mutex_t flashReqMutex;

//16k * 128
size_t dstAlloc_sz = PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
size_t srcAlloc_sz = PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
int dstAlloc;
int srcAlloc;
unsigned int ref_dstAlloc; 
unsigned int ref_srcAlloc; 
unsigned int* dstBuffer;
unsigned int* srcBuffer;


//---------------------------------
//Debug
//---------------------------------

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}

void LOG(int lvl, const char *format, ...) {
	if (lvl <= g_debuglevel) {
		va_list argptr;
		va_start(argptr, format);
		vfprintf(stderr, format, argptr);
		va_end(argptr);
	}
}


//---------------------------------
//Indication callback handlers
//---------------------------------
void FlashIndication::readDone(unsigned int tag) {
	LOG(1, "LOG: pagedone: tag=%d; inflight=%d\n", tag, curReadsInFlight );

	//check 
	if (g_checkdata) {
		bool pass = checkReadData(tag);
		g_testpass = (g_testpass && pass);
	}
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight --;
	if ( curReadsInFlight < 0 ) {
		LOG(0, "LOG: **ERROR: Read requests in flight cannot be negative %d\n", curReadsInFlight );
		curReadsInFlight = 0;
	}
	if ( readTagTable[tag].busy == false ) {
		LOG(0, "LOG: **ERROR: received unused buffer read done %d\n", tag);
		g_testpass = false;
	}
	readTagTable[tag].busy = false;
	pthread_mutex_unlock(&flashReqMutex);
}

void FlashIndication::writeDone(unsigned int tag) {
	LOG(1, "LOG: writedone, tag=%d\n", tag);
	
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight--;
	if ( curWritesInFlight < 0 ) {
		LOG(0, "LOG: **ERROR: Write requests in flight cannot be negative %d\n", curWritesInFlight );
		curWritesInFlight = 0;
	}
	if ( writeTagTable[tag].busy == false ) {
		LOG(0, "LOG: **ERROR: received unused buffer Write done %d\n", tag);
		g_testpass = false;
	}
	writeTagTable[tag].busy = false;
	pthread_mutex_unlock(&flashReqMutex);
}

void FlashIndication::eraseDone(unsigned int tag, unsigned int status) {
	LOG(1, "LOG: eraseDone, tag=%d, status=%d\n", tag, status);
	pthread_mutex_lock(&flashReqMutex);
	if (status != 0) {
		TagTableEntry e = eraseTagTable[tag];
		LOG(1, "LOG: detected bad block with tag=%d node=%d @%d %d %d 0\n", tag, e.node, e.bus, e.chip, e.block);
		//record bad block so check is skipped
		flashStatus[e.node][e.bus][e.chip][e.block] = BAD;
	}

	curErasesInFlight--;
	if ( curErasesInFlight < 0 ) {
		LOG(0, "LOG: **ERROR: erase requests in flight cannot be negative %d\n", curErasesInFlight );
		g_testpass = false;
		curErasesInFlight = 0;
	}
	if ( eraseTagTable[tag].busy == false ) {
		LOG(0, "LOG: **ERROR: received unused tag erase done %d\n", tag);
		g_testpass = false;
	}
	eraseTagTable[tag].busy = false;
	pthread_mutex_unlock(&flashReqMutex);
}




//----------------------------
// Initialization
//----------------------------
void auroraifc_start(int id) {
	device->setNetId(id);
	device->auroraStatus(0);
	sleep(1);
}


void init_dma() {
	MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(HostMemServerRequestS2H);
	MMURequestProxy *dmap = new MMURequestProxy(HostMMURequestS2H);
	DmaManager *dma = new DmaManager(dmap);
	MemServerIndication hostMemServerIndication(hostMemServerRequest, HostMemServerIndicationH2S);
	MMUIndication hostMMUIndication(dma, HostMMUIndicationH2S);

	fprintf(stderr, "Main::allocating memory...\n");

	device = new FlashRequestProxy(FlashRequestS2H);
	FlashIndication deviceIndication(FlashIndicationH2S);
	
	srcAlloc = portalAlloc(srcAlloc_sz, 1);
	dstAlloc = portalAlloc(dstAlloc_sz, 1);
	srcBuffer = (unsigned int *)portalMmap(srcAlloc, srcAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz);

	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	fprintf(stderr, "srcAlloc = %x\n", srcAlloc); 
	
	pthread_mutex_init(&flashReqMutex, NULL);

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	//defaultPoller->portalExec_timeout = 0;

	portalCacheFlush(dstAlloc, dstBuffer, dstAlloc_sz, 1);
	portalCacheFlush(srcAlloc, srcBuffer, srcAlloc_sz, 1);
	ref_dstAlloc = dma->reference(dstAlloc);
	ref_srcAlloc = dma->reference(srcAlloc);

	device->setDmaWriteRef(ref_dstAlloc);
	device->setDmaReadRef(ref_srcAlloc);
	for (int t = 0; t < NUM_TAGS; t++) {
		readTagTable[t].busy = false;
		writeTagTable[t].busy = false;
		int byteOffset = t * PAGE_SIZE;
		//printf("byteOffset=%x\n", byteOffset); fflush(stdout);
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}
	
	for (int node=0; node<NUM_NODES; node++) {
		for (int blk=0; blk<BLOCKS_PER_CHIP; blk++) {
			for (int c=0; c<CHIPS_PER_BUS; c++) {
				for (int bus=0; bus< CHIPS_PER_BUS; bus++) {
					flashStatus[node][bus][c][blk] = UNINIT;
				}
			}
		}
	}


	for (int t = 0; t < NUM_TAGS; t++) {
		for (unsigned int i = 0; i < PAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0;
			writeBuffers[t][i] = 0;
		}
	}
}



//----------------------------
// Flash operations
//----------------------------

unsigned int hashAddrToData(int node, int bus, int chip, int blk, int word) {
	return ((node<<27) + (bus<<24) + (chip<<20) + (blk<<16) + word);
	//return ((bus<<24) + (chip<<20) + (blk<<16) + word);
}


bool checkReadData(int tag) {
	TagTableEntry e = readTagTable[tag];
	bool pass = true;
	unsigned int goldenData;
	if (flashStatus[e.node][e.bus][e.chip][e.block]==WRITTEN) {
		int numErrors = 0;
		for (unsigned int word=0; word<PAGE_SIZE_VALID/sizeof(unsigned int); word++) {
			goldenData = hashAddrToData(e.node, e.bus, e.chip, e.block, word);
			if (goldenData != readBuffers[tag][word]) {
				LOG(0, "LOG: **ERROR: read data mismatch [%d]! Expected: %x, read: %x\n", word, goldenData, readBuffers[tag][word]);
				numErrors++; 
				pass = false;
			}
		}
		if (numErrors==0) {
			LOG(0, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.node][e.bus][e.chip][e.block]==ERASED) {
		//only check first word. It may return 0 if bad block, or -1 if erased
		if (readBuffers[tag][0]==(unsigned int)-1) {
			LOG(0, "LOG: Read check passed on erased block!\n");
		}
		else if (readBuffers[tag][0]==0) {
			LOG(0, "LOG: Warning: potential bad block, read erased data 0\n");
		}
		else {
			LOG(0, "LOG: **ERROR: read data mismatch! Expected: ERASED, read: %x\n", readBuffers[tag][0]);
			pass = false;
		}
	}
	else if (flashStatus[e.node][e.bus][e.chip][e.block]==BAD) {
		LOG(0, "LOG: WARNING: Bad block was recorded. Skipping check. tag=%d node=%d @%d %d %d 0\n",
				tag, e.node, e.bus, e.chip, e.block);

	}
	else {
		LOG(0, "LOG: **ERROR: flash block state unknown. Did you erase before write?\n");
		pass = false; 
	}
	return pass;
}



int getNumReadsInFlight() { return curReadsInFlight; }
int getNumWritesInFlight() { return curWritesInFlight; }
int getNumErasesInFlight() { return curErasesInFlight; }



int waitIdleEraseTag() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);
		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !eraseTagTable[t].busy ) {
				eraseTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
		pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}


int waitIdleWriteBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !writeTagTable[t].busy) {
				writeTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}



int waitIdleReadBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
		pthread_mutex_lock(&flashReqMutex);
		for ( int t = 0; t < NUM_TAGS; t++ ) { 
			if ( !readTagTable[t].busy ) {
				readTagTable[t].busy = true;
				tag = t;
				break;
			}
		}

		pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}




void eraseBlock(int node, int bus, int chip, int block, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curErasesInFlight ++;
	eraseTagTable[tag].node = node;
	eraseTagTable[tag].bus = bus;
	eraseTagTable[tag].chip = chip;
	eraseTagTable[tag].block = block;
	flashStatus[node][bus][chip][block] = ERASED;
	pthread_mutex_unlock(&flashReqMutex);

	LOG(1, "LOG: sending erase block request with tag=%d to node=%d @%d %d %d 0\n", tag, node, bus, chip, block );
	device->eraseBlock(node,bus,chip,block,tag);
}



void writePage(int node, int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight ++;
	//if block is bad we send the command anyway, but skip read checks
	if (flashStatus[node][bus][chip][block] != BAD) {
		flashStatus[node][bus][chip][block] = WRITTEN;
	}
	pthread_mutex_unlock(&flashReqMutex);

	LOG(1, "LOG: sending write page request to node=%d with tag=%d @%d %d %d %d\n", node, tag, bus, chip, block, page );
	device->writePage(node,bus,chip,block,page,tag);
}

void readPage(int node, int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	readTagTable[tag].node = node;
	readTagTable[tag].bus = bus;
	readTagTable[tag].chip = chip;
	readTagTable[tag].block = block;
	pthread_mutex_unlock(&flashReqMutex);

	LOG(1, "LOG: sending read page request to node=%d with tag=%d @%d %d %d %d\n", node, tag, bus, chip, block, page );
	device->readPage(node,bus,chip,block,page,tag);
}






