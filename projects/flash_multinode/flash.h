#ifndef __FLASH_H__
#define __FLASH_H__

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdarg.h>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "FlashIndication.h"
#include "FlashRequest.h"

#define PAGES_PER_BLOCK 1
#define BLOCKS_PER_CHIP 1024  //Be careful when using this during concurrent write test
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8
#define NUM_NODES 4

#define PAGE_SIZE (8192*2)
#define PAGE_SIZE_VALID (8224)
#define NUM_TAGS 128



typedef enum {
	UNINIT,
	ERASED,
	WRITTEN, 
	BAD
} FlashStatusT;

typedef struct {
	bool busy;
	int node;
	int bus;
	int chip;
	int block;
} TagTableEntry;

//DECLARATION of globals externs
extern int g_debuglevel;
extern bool g_testpass;
extern bool g_checkdata;
extern FlashRequestProxy *device;
extern unsigned int* readBuffers[NUM_TAGS];
extern unsigned int* writeBuffers[NUM_TAGS];

//---------------------------------
//Debug
//---------------------------------
double timespec_diff_sec( timespec start, timespec end );
void LOG(int lvl, const char *format, ...);

//---------------------------------
//Indication callback handlers
//---------------------------------
class FlashIndication : public FlashIndicationWrapper
{
	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}
		virtual void readDone(unsigned int tag);
		virtual void writeDone(unsigned int tag);
		virtual void eraseDone(unsigned int tag, unsigned int status);

		virtual void debugDumpResp (unsigned int debug0, unsigned int debug1,  unsigned int debug2, unsigned int debug3, unsigned int debug4, unsigned int debug5) {
			LOG(0, "LOG: DEBUG DUMP: gearSend = %d, gearRec = %d, aurSend = %d, aurRec = %d, readSend=%d, writeSend=%d\n", debug0, debug1, debug2, debug3, debug4, debug5);
		}

		virtual void debugAuroraExt(unsigned int debug0, unsigned int debug1, unsigned int debug2, unsigned int debug3) {
			LOG(0, "LOG: Aurora Ext: cmdHi = %x, cmdLo = %x\n", debug0, debug1);
		}
		
		virtual void hexDump(unsigned int hex) {
			LOG(0, "LOG: hexDump=%x\n", hex);
		}


};

//----------------------------
// Initialization
//----------------------------
void auroraifc_start(int id);
void init_dma();

//----------------------------
// Flash operations
//----------------------------
unsigned int hashAddrToData(int node, int bus, int chip, int blk, int word);
bool checkReadData(int tag);
int getNumReadsInFlight();
int getNumWritesInFlight();
int getNumErasesInFlight();

int waitIdleEraseTag();
int waitIdleWriteBuffer();
int waitIdleReadBuffer();
void eraseBlock(int node, int bus, int chip, int block, int tag);
void writePage(int node, int bus, int chip, int block, int page, int tag);
void readPage(int node, int bus, int chip, int block, int page, int tag);


#endif
