#include "storagebridge.h"

int bridgeBufferAlloc;
unsigned int ref_bridgeBufferAlloc;
unsigned int* bridgeBuffer;
unsigned int* bridgeBuffers[BRIDGE_BUFFER_COUNT];

int numBytes = (1 << (10 +4))*BRIDGE_BUFFER_COUNT; //16KB buffer, to be safe
size_t alloc_sz = numBytes*sizeof(unsigned char);

StorageBridgeRequestProxy *bridge_device = 0;
StorageBridgeIndication *bridgeIndication = 0;


void storagebridge_init() {
	bridge_device = new StorageBridgeRequestProxy(IfcNames_StorageBridgeRequest);
	bridgeIndication = new StorageBridgeIndication(IfcNames_StorageBridgeIndication);

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
	}
}
