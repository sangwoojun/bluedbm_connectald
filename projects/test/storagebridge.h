#ifndef __STORAGEBRIDGE_H__
#define __STORAGEBRIDGE_H__
#include "connectal.h"

#define BRIDGE_BUFFER_COUNT 128

class StorageBridgeIndication : public StorageBridgeIndicationWrapper
{
private:
	StorageBridgeRequestProxy* device;
public:
	StorageBridgeIndication(unsigned int id, StorageBridgeRequestProxy* _device) : StorageBridgeIndicationWrapper(id) {device = _device;}

	virtual void writePage(unsigned int channel, unsigned int chip, unsigned int block, unsigned int page, unsigned int bufidx);
	virtual void readPage(unsigned int channel, unsigned int chip, unsigned int block, unsigned int page, unsigned int bufidx, unsigned int targetbufidx);
};

void storagebridge_init();
void storagebridge_alloc(DmaManager* dma);
#endif
