#ifndef __SW_PLATFORM__
#define __SW_PLATFORM__
#include <time.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <stdint.h>

#include "PlatformIndicationWrapper.h"
#include "PlatformRequestProxy.h"

void platform(PlatformRequestProxy* device);
void platformIndicationSetup();

#endif
