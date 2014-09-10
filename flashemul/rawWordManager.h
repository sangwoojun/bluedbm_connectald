#ifndef __RAW__WORD_MANAGER__
#define __RAW__WORD_MANAGER__

#include <pthread.h>

#define RAW_WORD_COUNT 1024
class RawWordManager {
public:
	static RawWordManager* getInstance();
	void writeWord(unsigned long long int w);
	bool readWord(unsigned long long int &w);
private:
	static RawWordManager* instance;

	RawWordManager();

	unsigned long long rawWordBuffer[RAW_WORD_COUNT];
	int rawWordHead;
	int rawWordTail;

	pthread_mutex_t wordMutex;

};

#endif
