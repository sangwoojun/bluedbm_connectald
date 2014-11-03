#include "storagebridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int bridgeBufferAlloc;
unsigned int ref_bridgeBufferAlloc;
unsigned int* bridgeBuffer;
unsigned int* bridgeBuffers[BRIDGE_BUFFER_COUNT];

int numBytes = (1 << (10 +4))*BRIDGE_BUFFER_COUNT; //16KB buffer, to be safe
size_t alloc_sz = numBytes*sizeof(unsigned char);

StorageBridgeRequestProxy *bridge_device = 0;
StorageBridgeIndication *bridgeIndication = 0;

int pageSize = (1<< (10+3))+128; //8KB + 128
int busEmulSize = pageSize*(1024*1024/8); // 1GB actual data
#define EMUL_BUFFER_COUNT 4
unsigned int *emulBuffers[EMUL_BUFFER_COUNT];


void storagebridge_init() {
	bridge_device = new StorageBridgeRequestProxy(IfcNames_StorageBridgeRequest);
	bridgeIndication = new StorageBridgeIndication(IfcNames_StorageBridgeIndication, bridge_device);

	bridgeBufferAlloc = portalAlloc(alloc_sz);
	bridgeBuffer = (unsigned int*)portalMmap(bridgeBufferAlloc, alloc_sz);
}

void storagebridge_alloc(DmaManager* dma) {
	portalDCacheFlushInval(bridgeBufferAlloc, alloc_sz, bridgeBuffer);
	ref_bridgeBufferAlloc = dma->reference(bridgeBufferAlloc);

	for ( int i = 0; i < BRIDGE_BUFFER_COUNT; i++ ) {
		int offset = i*1024*16;
		bridgeBuffers[i] = bridgeBuffer + (offset/sizeof(unsigned int));
		bridge_device->addBridgeBuffer(ref_bridgeBufferAlloc, offset, i);

		for ( int j = 0; j < (8192+128)/4; j++ ) {
			bridgeBuffers[i][j] = (i<<16) + j;
		}
	}

	for ( int i = 0; i < EMUL_BUFFER_COUNT; i++ ) {
		emulBuffers[i] = (unsigned int*)malloc(sizeof(unsigned char) * busEmulSize);
	}
}

int getPageOffset(unsigned int chip, unsigned int block, unsigned int page) {
	int offset = page + (block << 8) + (chip <<16);
}

// Write data to emulated flash
// Data exists in bridgeBuffers[bufidx] when this is called 
void StorageBridgeIndication::writePage(unsigned int channel, unsigned int chip, unsigned int block, unsigned int page, unsigned int bufidx) {
	int pageOffset = getPageOffset(chip, block, page);
	int byteOffset = pageOffset*pageSize;
	memcpy(((char*)emulBuffers[channel])+byteOffset,
		bridgeBuffers[bufidx], pageSize);
	
	device->writeBufferDone(channel, bufidx);

	if ( verbose ) {
		printf( "storagebridge writedone %d %d \n", channel, bufidx );
	}
}

// Read data from emulated flash
// Data should be copied to bridgeBuffers[bufidx] 
// before calling "readBufferReady"
void StorageBridgeIndication::readPage(unsigned int channel, unsigned int chip, unsigned int block, unsigned int page, unsigned int bufidx, unsigned int targetbufidx) {
	int pageOffset = getPageOffset(chip, block, page);
	int byteOffset = pageOffset*pageSize;
	memcpy(
		bridgeBuffers[bufidx], 
		((char*)emulBuffers[channel])+byteOffset,
		pageSize);

	device->readBufferReady(channel, bufidx, targetbufidx);
	if ( verbose ) printf( "storagebridge readPage %d %d \n", channel, bufidx );
}
