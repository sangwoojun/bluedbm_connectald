#include <stdio.h>

#include <cstddef>
#include "rawWordManager.h"

RawWordManager::RawWordManager()
	{rawWordHead = 0; rawWordTail=1;
	pthread_mutex_init(&wordMutex, NULL);
	}

RawWordManager* RawWordManager::instance = NULL;

RawWordManager* RawWordManager::getInstance() {
	if ( !instance ) instance = new RawWordManager();

	return instance;
}

void 
RawWordManager::writeWord(unsigned long long int data) {
	printf( "\t\t** %llx\n", data );
	/*
	pthread_mutex_lock(&wordMutex);
	if ( rawWordTail == rawWordHead ) return;

	rawWordBuffer[rawWordTail] = data;
	rawWordTail ++;
	if ( rawWordTail >= RAW_WORD_COUNT ) {
		rawWordTail = 0;
	}
	pthread_mutex_unlock(&wordMutex);
	*/
}

bool
RawWordManager::readWord(unsigned long long int& w) {
	if ( rawWordTail == rawWordHead ) return false;
	pthread_mutex_lock(&wordMutex);

	w = rawWordBuffer[rawWordHead];
	rawWordHead ++;
	if ( rawWordHead >= RAW_WORD_COUNT ) {
		rawWordHead = 0;
	}
	pthread_mutex_unlock(&wordMutex);
	return true;
}
