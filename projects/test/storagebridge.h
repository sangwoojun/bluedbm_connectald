#ifndef __STORAGEBRIDGE_H__
#define __STORAGEBRIDGE_H__
#include "connectal.h"

#define BRIDGE_BUFFER_COUNT 128

class StorageBridgeIndication : public StorageBridgeIndicationWrapper
{
public:
	StorageBridgeIndication(unsigned int id) : StorageBridgeIndicationWrapper(id) {}

	virtual void writePage(unsigned int pageIdx, unsigned int bufidx) {
		//printf( "Emulated flash write page %d %d\n", pageIdx, bufidx );
	}
};

void storagebridge_init();
void storagebridge_alloc(DmaManager* dma);
#endif
