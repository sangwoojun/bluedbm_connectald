#include <linux/delay.h>  // msleep
#include <linux/kthread.h>
#include <linux/types.h>

#include "dmaManager.h"
#include "GeneratedTypes.h" 
#include "portalmem.h"

#define MAX_INDARRAY 4
/*#define MAX_INDARRAY 6*/

DECLARE_COMPLETION(worker_completion);
static DmaManagerPrivate priv;
static PortalInternal intarr[MAX_INDARRAY];
static sem_t test_sem;

/* call-back functions */
void FlashIndicationreadDone_cb (struct PortalInternal *p, const uint32_t tag)
{
	PORTAL_PRINTF ( "cb: FlashIndicationWrapperreadDone_cb (tag = %x)\n", tag);
	sem_post (&test_sem);
}

void FlashIndicationwriteDone_cb (  struct PortalInternal *p, const uint32_t tag )
{
	PORTAL_PRINTF ( "cb: FlashIndicationWrapperwriteDone_cb (tag = %x)\n", tag);
	sem_post (&test_sem);
}

void FlashIndicationeraseDone_cb (  struct PortalInternal *p, const uint32_t tag, const uint32_t status )
{
	PORTAL_PRINTF ( "cb: FlashIndicationWrappereraseDone_cb (tag = %x, status = %x)\n", tag, status);
	sem_post (&test_sem);
}

void FlashIndicationdebugDumpResp_cb (  struct PortalInternal *p, const uint32_t debug0, const uint32_t debug1, const uint32_t debug2, const uint32_t debug3 )
{
	PORTAL_PRINTF ( "cb: FlashIndicationWrapperdebugDumpResp_cb\n");
	sem_post (&test_sem);
}

void MMUIndicationWrapperidResponse_cb (  struct PortalInternal *p, const uint32_t sglId ) 
{
	PORTAL_PRINTF ("cb: MMUConfigIndicationWrapperidResponse_cb\n");
	priv.sglId = sglId;
	sem_post (&priv.sglIdSem);
}

void MMUIndicationWrapperconfigResp_cb (  struct PortalInternal *p, const uint32_t pointer )
{
	PORTAL_PRINTF ("cb: MMUConfigIndicationWrapperconfigResp_cb(physAddr=%x)\n", pointer);
	sem_post (&priv.confSem);
}

void MMUIndicationWrappererror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t pointer, const uint64_t offset, const uint64_t extra ) 
{
	PORTAL_PRINTF ("cb: MMUConfigIndicationWrappererror_cb\n");
}

/*
void DmaDebugIndicationWrapperaddrResponse_cb (  struct PortalInternal *p, const uint64_t physAddr )
{
	PORTAL_PRINTF ("cb: DmaDebugIndicationWrapperaddrResponse_cb\n");
}

void DmaDebugIndicationWrapperreportStateDbg_cb (  struct PortalInternal *p, const DmaDbgRec rec )
{
	PORTAL_PRINTF ("cb: DmaDebugIndicationWrapperreportStateDbg_cb\n");
	sem_post (&priv.dbgSem);
}

void DmaDebugIndicationWrapperreportMemoryTraffic_cb (  struct PortalInternal *p, const uint64_t words )
{
	PORTAL_PRINTF ("cb: DmaDebugIndicationWrapperreportMemoryTraffic_cb\n");
	priv.mtCnt = words;
	sem_post (&priv.mtSem);
}

void DmaDebugIndicationWrappererror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t pointer, const uint64_t offset, const uint64_t extra ) 
{
	PORTAL_PRINTF ("cb: DmaDebugIndicationWrappererror_cb\n");
}
*/

void manual_event(void)
{
	/*
	int i;
	for (i = 0; i < MAX_INDARRAY; i++) {
		PortalInternal *instance = &intarr[i];
		volatile unsigned int *map_base = instance->map_base;
		unsigned int queue_status;
		while ((queue_status= READL(instance, &map_base[IND_REG_QUEUE_STATUS]))) {
			unsigned int int_src, int_en, ind_count;
			int_src = READL (instance, &map_base[IND_REG_INTERRUPT_FLAG]);
			int_en = READL (instance, &map_base[IND_REG_INTERRUPT_MASK]);
			ind_count = READL (instance, &map_base[IND_REG_INTERRUPT_COUNT]);
			instance->handler (instance, queue_status-1);
		}
	}
	*/
	int i;
	for (i = 0; i < MAX_INDARRAY; i++)
		portalCheckIndication(&intarr[i]);
}

void* pthread_worker (void* arg) 
{
	while (1) {
		manual_event ();
		msleep (0);
		if (kthread_should_stop ()) {
			PORTAL_PRINTF ("nandsim_worker_thread_fn ends");
			break;
		}
	}
	complete (&worker_completion);
	return 0;
}

#define FLASH_PAGE_SIZE 8192*2
#define FLASH_PAGE_SIZE_VALID (8224)
#define NUM_TAGS 128

int srcAlloc;
int dstAlloc;
size_t dstAlloc_sz = FLASH_PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
size_t srcAlloc_sz = FLASH_PAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
unsigned int ref_dstAlloc; 
unsigned int ref_srcAlloc; 
unsigned int* dstBuffer;
unsigned int* srcBuffer;
unsigned int* readBuffers[NUM_TAGS];
unsigned int* writeBuffers[NUM_TAGS];
bool dstBufBusy[NUM_TAGS]; 
bool srcBufBusy[NUM_TAGS]; 
bool eraseTagBusy[NUM_TAGS]; 

MMUIndicationCb MMUIndication_cbTable = {
	MMUIndicationWrapperidResponse_cb,
	MMUIndicationWrapperconfigResp_cb,
	MMUIndicationWrappererror_cb,
};

FlashIndicationCb FlashIndication_cbTable = {
	FlashIndicationreadDone_cb,
	FlashIndicationwriteDone_cb,
	FlashIndicationeraseDone_cb,
	FlashIndicationdebugDumpResp_cb,
};


int main (int argc, const char **argv)
{
	int i = 0, t = 0;
  	pthread_t tid = 0;

	/* create portals */
	init_portal_internal (&intarr[2], IfcNames_HostMMURequest, NULL, NULL, NULL, NULL, MMURequest_reqinfo); // fpga3
	init_portal_internal (&intarr[0], IfcNames_HostMMUIndication, MMUIndication_handleMessage, &MMUIndication_cbTable, NULL, NULL, MMUIndication_reqinfo); // fpga1
	init_portal_internal (&intarr[3], IfcNames_FlashRequest, NULL, NULL, NULL, NULL, FlashRequest_reqinfo); // fpga4
	init_portal_internal (&intarr[1], IfcNames_FlashIndication, FlashIndication_handleMessage, &FlashIndication_cbTable, NULL, NULL, FlashIndication_reqinfo); // fpga2

	sem_init (&test_sem, 0, 0);
	DmaManager_init (&priv, NULL, &intarr[2]);
	srcAlloc = portalAlloc (srcAlloc_sz);
	dstAlloc = portalAlloc (dstAlloc_sz);

	printk (KERN_INFO "%llu", sizeof (uint32_t));

	/* create and run a thread for message handling */
	if (pthread_create (&tid, NULL, pthread_worker, NULL)) {
		PORTAL_PRINTF ("kthread_create failed\n");
		return 1;
	}

	/* allocate memory */
	srcBuffer = (unsigned int *)portalMmap (srcAlloc, srcAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap (dstAlloc, dstAlloc_sz);

	PORTAL_PRINTF ("dstAlloc = %x\n", dstAlloc); 
	PORTAL_PRINTF ("srcAlloc = %x\n", srcAlloc); 
	
	portalDCacheFlushInval(dstAlloc, dstAlloc_sz, dstBuffer);
	portalDCacheFlushInval(srcAlloc, srcAlloc_sz, srcBuffer);
	ref_dstAlloc = DmaManager_reference (&priv, dstAlloc);
	ref_srcAlloc = DmaManager_reference (&priv, srcAlloc);

	msleep (1000);
	PORTAL_PRINTF ("assign memory\n");

	/* assign & initialize memory */
	for (t = 0; t < NUM_TAGS; t++) {
		int byteOffset = t * FLASH_PAGE_SIZE;
		dstBufBusy[t] = false;
		srcBufBusy[t] = false;
		FlashRequest_addDmaWriteRefs (&intarr[3], ref_dstAlloc, byteOffset, t);
		FlashRequest_addDmaReadRefs (&intarr[3], ref_srcAlloc, byteOffset, t);
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}

	for (t = 0; t < NUM_TAGS; t++) {
		for (i = 0; i < FLASH_PAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0;
			writeBuffers[t][i] = i;
		}
	}

	/*goto exit;*/


	/* init a device */
	PORTAL_PRINTF ("init flash\n");
	FlashRequest_start (&intarr[3], 0);
	FlashRequest_setDebugVals (&intarr[3], 0, 0);
	FlashRequest_debugDumpReq (&intarr[3], 0);
	sem_wait (&test_sem);
	msleep (1000);
	FlashRequest_debugDumpReq (&intarr[3], 0);
	sem_wait (&test_sem);

	/* test Flash operations */
	PORTAL_PRINTF ("OP1: Block Erase\n");
	FlashRequest_eraseBlock (&intarr[3], 0, 0, 0, 0);
	sem_wait (&test_sem);

	PORTAL_PRINTF ("OP2: Page Read (all FFs)\n");
	FlashRequest_readPage (&intarr[3], 0, 0, 0, 1, 0);
	sem_wait (&test_sem);
	for (t = 0; t < 1; t++ ) {
		for (i = 0; i < FLASH_PAGE_SIZE_VALID/sizeof(unsigned int); i++ ) {
			PORTAL_PRINTF ("%x %d %x\n", t, i, readBuffers[t][i] );
		}
	}

	PORTAL_PRINTF ("OP3: Write Page\n");
	FlashRequest_writePage (&intarr[3], 0, 0, 0, 1, 0);
	sem_wait (&test_sem);

	PORTAL_PRINTF ("OP4: Page Read\n");
	FlashRequest_readPage (&intarr[3], 0, 0, 0, 1, 0); // 0, 1, 2, 3, 4 ...
	sem_wait (&test_sem);
	for (t = 0; t < 1; t++ ) {
		for (i = 0; i < FLASH_PAGE_SIZE_VALID/sizeof(unsigned int); i++ ) {
			PORTAL_PRINTF ("%x %d %d\n", t, i, readBuffers[t][i] );
		}
	}

	PORTAL_PRINTF( "Main: all done (%llu, %llu, %llu)\n", sizeof (unsigned int), sizeof(uint32_t), sizeof(uint64_t));
exit:
#ifdef __KERNEL__
	if (tid && !kthread_stop (tid)) {
		PORTAL_PRINTF ("kthread stops\n");
	}
	wait_for_completion (&worker_completion);
#endif
	PORTAL_PRINTF ("Main: ends\n");

	return 0;
}

