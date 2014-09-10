#include "platform.hpp"

extern int readPage(unsigned long long pageIdx);
extern int writePage(unsigned long long pageIdx);
extern unsigned int *hostBuffer;
extern void waitTagFlush(int reqs, int resps);
extern int maxTagUsed;
extern unsigned int pageReadTotal;
extern unsigned int pageWriteTotal;

unsigned int i2cBuffer = 0;
int i2cReadCount = 0;

bool i2cReadDone;
unsigned char i2cReadData;

unsigned char i2cRead(PlatformRequestProxy* device, unsigned char slave, unsigned char addr) {
	i2cReadDone = false;
	unsigned int c = (addr<<8) + (slave<<16);
	device->i2cRequest(c);
	usleep(1000);
	while ( i2cReadDone == false ) usleep(1000);
	return i2cReadData;
}
void i2cWrite(PlatformRequestProxy* device, unsigned char slave, unsigned char addr, unsigned char data) {
	unsigned int c = data + (addr<<8) + (slave<<16) + (1<<23);
	device->i2cRequest(c);
	usleep(1000);
}

class PlatformIndication : public PlatformIndicationWrapper 
{
	public:
	PlatformIndication(unsigned int id) : PlatformIndicationWrapper(id){}

	virtual void rawWordTest(uint64_t d) {
		printf( "[rawWord] %llx\n",d );
		fflush(stdout);
	}
	virtual void i2cResult(unsigned int ret) {
		//printf( "[i2c0] : %x\n", ret );
		//fflush(stdout);

		i2cReadData = (unsigned char)ret;
		i2cReadDone = true;
		//i2cBuffer = (i2cBuffer << 8) + ret;
		//i2cReadCount ++;
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

void platform(PlatformRequestProxy* device) {

	unsigned int i2c_switch_addr = 0x74;
	unsigned int i2c_fmc1_data = 0x1;
	unsigned int i2c_fmc2_data = 0x2;
	i2cWrite(device, i2c_switch_addr, 0, i2c_fmc1_data);
	//i2cWrite(device, i2c_switch_addr, 0, i2c_fmc1_data);
	unsigned int i2c_si570_addr = 0x5D;
	unsigned int si570_configs = 0;
	for ( int i = 0; i < 4; i++ ) {
		i2cWrite(device, 0x70+i, 0, 1);
	}

	// i2cWrite(device, i2c_si570_addr, 135, 1); // reset Si570
/*
	for ( int i = 7; i < 13; i++ ) {
		unsigned char d = i2cRead(device, i2c_si570_addr, i);
		printf( "%2d %x\n", i, d );
	}
*/
	printf( "---\n" ); fflush(stdout);
	
	for ( int i = 7; i < 13; i++ ) {
		unsigned char d = 0xff;
		int c = 0;
		while ( d == 0xff && c < 16) {
			d = i2cRead(device, i2c_si570_addr, i);
			c++;
		}
		printf( "%2d %x\n", i, d );
	}

	i2cWrite(device, i2c_si570_addr, 137, 1<<4);
	usleep(2000);

	// 125 MHz
	i2cWrite(device, i2c_si570_addr, 7, 0x21);
	i2cWrite(device, i2c_si570_addr, 8, 0xc2);
	i2cWrite(device, i2c_si570_addr, 9, 0xBB);
	i2cWrite(device, i2c_si570_addr, 10, 0xFF);
	i2cWrite(device, i2c_si570_addr, 11, 0xe4);
	i2cWrite(device, i2c_si570_addr, 12, 0x14);
	
	// 625 MHz
	/*
	i2cWrite(device, i2c_si570_addr, 7, 0x00);
	i2cWrite(device, i2c_si570_addr, 8, 0x42);
	i2cWrite(device, i2c_si570_addr, 9, 0xBB);
	i2cWrite(device, i2c_si570_addr, 10, 0xFF);
	i2cWrite(device, i2c_si570_addr, 11, 0xe4);
	i2cWrite(device, i2c_si570_addr, 12, 0x14);
	*/
	
	/*
	// 275
	i2cWrite(device, i2c_si570_addr, 7, 0x01);
	i2cWrite(device, i2c_si570_addr, 8, 0x03);
	i2cWrite(device, i2c_si570_addr, 9, 0x01);
	i2cWrite(device, i2c_si570_addr, 10, 0xFF);
	i2cWrite(device, i2c_si570_addr, 11, 0xE1);
	i2cWrite(device, i2c_si570_addr, 12, 0x49);
	*/

	usleep(2000);
	i2cWrite(device, i2c_si570_addr, 137, 0);
	usleep(2000);
	i2cWrite(device, i2c_si570_addr, 135, 1<<6);
	usleep(2000);
	device->resetAurora(0);
	usleep(2000);

	device->start(0);
	for ( int i = 7; i < 13; i++ ) {
		unsigned char d = 0xff;
		int c = 0;
		while ( d == 0xff && c < 16) {
			d = i2cRead(device, i2c_si570_addr, i);
			c++;
		}
		printf( "%2d %x\n", i, d );
	}

	//for ( int i = 0; i < 5; i++ ) {
	while (1) {
		device->auroraStatus(0);
		sleep(1);
	}
	
	for ( int i = 0; i < 1024*2*64; i++ ) {
		hostBuffer[i] = i;
	}
	int writeReqSent = 0;
	for ( int i = 0; i < 1024*2; i++ ) {
		fflush(stdout);
		int widx = writePage(i);
		//int widx = writePage(i);
		writeReqSent++;
	}
	waitTagFlush(writeReqSent, pageWriteTotal);
	printf( "\t\t**Write done\n" );
	fflush(stdout);
	
	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);
	
	int readReqSent = 0;
	//for ( int i = 0; i < 1024; i++ ) {
	for ( int i = 0; i < 1024*256; i++ ) {
	  readPage(i);
	  readReqSent ++;
	  //if ( i % 1024 == 0) 
	  //printf( "--%d\n", i); 
	  //fflush(stdout);
	}
	waitTagFlush(readReqSent, pageReadTotal);
	clock_gettime(CLOCK_REALTIME, & now);
	printf( "Total pages read: %d (%d)\n", pageReadTotal, maxTagUsed );
	printf( "elapsed : %f\n", timespec_diff_sec(start,now) );
	
	/*
	printf( "---\n\n" );
	for ( int i = 0; i < 64; i++ ) {
		int ival = hostBuffer[i*1024];
		for ( int j = 0; j < 1024; j++ ) {
			int idx = i*1024 + j;
			int rval = hostBuffer[idx];
			if ( ival != rval ) {
				printf( "!!! %d  != %d (%d:%d)\n", ival, rval, idx, i );
			}
			ival++;
		}
	}
	*/
}
