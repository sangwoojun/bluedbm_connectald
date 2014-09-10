#include "platform.hpp"

extern int readPage(unsigned long long pageIdx);
extern int writePage(unsigned long long pageIdx);
extern unsigned int *hostBuffer;
extern void waitTagFlush(int reqs, int resps);
extern int maxTagUsed;
extern unsigned int pageReadTotal;
extern unsigned int pageWriteTotal;

int curRequestedIn = 0;
bool bMrDone;
class PlatformIndication : public PlatformIndicationWrapper 
{
	public:
	PlatformIndication(unsigned int id) : PlatformIndicationWrapper(id){}

	virtual void mrDone(uint32_t d) {bMrDone = true; }
	virtual void sendWord8(uint64_t d) {}
	virtual void sendWord4(uint32_t d) {}
	virtual void sendKey(uint64_t key) {
		printf( "[key] %llx\n",key );
		fflush(stdout);
	}

	virtual void rawWordTest(uint64_t d) {
		printf( "[rawWord] %llx\n",d );
		fflush(stdout);
	}
	virtual void requestWords(unsigned int count) {
		curRequestedIn += count;
		//printf( "curRequestedIn: %d\n", curRequestedIn );
	}
};

PlatformIndication *platformIndication;
void platformIndicationSetup() {
	platformIndication = 0;
	platformIndication = new PlatformIndication(IfcNames_PlatformIndication);
}


double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}

#define MAP_VALUE8_COUNT 2
#define MAP_VALUE4_COUNT 1
typedef struct {
	uint64_t key;
	uint64_t value8[MAP_VALUE8_COUNT];
	uint32_t value4[MAP_VALUE4_COUNT];
} MapHeader;

void send_mapData(MapHeader* mh, PlatformRequestProxy* device) {
	while ( curRequestedIn <= 0 ) usleep(1000);

	for ( int i = 0; i < MAP_VALUE8_COUNT; i++ ) {
		device->sendWord8(mh->value8[i]);
	}
	for ( int i = 0; i < MAP_VALUE4_COUNT; i++ ) {
		device->sendWord4(mh->value4[i]);
	}
	device->sendKey(mh->key);
	curRequestedIn --;
}

void platform(PlatformRequestProxy* device) {
	curRequestedIn = 0;
	bMrDone = false;

	printf( "---\n" ); fflush(stdout);
	MapHeader mh;
	mh.key = 0xdeadbeef;
	mh.value8[0] = 0x1234567898765432;
	mh.value8[1] = 0xbeefbeefd00dd0dd;
	mh.value4[0] = 0xc001d00d;
	for ( int i = 0; i < 128; i++ ) {
	send_mapData(&mh, device);
	send_mapData(&mh, device);
	send_mapData(&mh, device);
		mh.key ++;
	}
	device->finalize(0);
	/*
	uint64_t* pmh = (uint64_t*)&mh;
	for ( int i = 0; i < sizeof(MapHeader)/sizeof(uint64_t)+1; i++ ) {
		device->sendWord(*pmh);
		pmh++;
	}
	*/


	device->start(0);
	while(bMrDone == false) sleep(1);
}
