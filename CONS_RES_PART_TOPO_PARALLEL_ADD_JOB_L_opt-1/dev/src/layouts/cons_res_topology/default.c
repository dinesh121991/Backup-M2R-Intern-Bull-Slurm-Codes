/** TODO: copyright notice */

#include "slurm/slurm.h"

#include "src/common/layouts_mgr.h"
#include "src/common/layout.h"
#include "src/common/entity.h"
#include "src/common/log.h"

/*
#include "src/common/slurm_topology.h"
#include "src/common/xmalloc.h"


#if defined (__APPLE__)
int switch_levels __attribute__((weak_import));
struct switch_record *switch_record_table __attribute__((weak_import));
int switch_record_cnt __attribute__((weak_import));
#else
int switch_levels;
struct switch_record *switch_record_table;
int switch_record_cnt;
#endif

#define L_SELECTED_NODE_CNT "AvailableNodeCountInLevel-"
#define L_SELECTED_CPU_CNT "AvailableCpuCountInLevel-"
#define L_ALLOCATED_CPU_CNT "AllocatedCpuCountInLevel-"
#define L_NUM_CPU_CNT "NumCpuCountInLevel-"

#define L_NUM_NODE_CNT "NumNodeCountInLevel-"
#define L_NUM_SOCKET_CNT "NumSocketCountInLevel-"
#define L_NUM_CORE_CNT "NumCoreCountInLevel-"
#define L_ALLOCATED_NODE_CNT "NumNodeCountInLevel-"
#define L_ALLOCATED_SOCKET_CNT "NumSocketCountInLevel-"
#define L_ALLOCATED_CORE_CNT "NumCoreCountInLevel-"

int i;*/

const char plugin_name[] = "Consumable resources layout Network (CRLN) plugin";
const char plugin_type[] = "layouts/cons_res_partition";
const uint32_t plugin_version = 100;

s_p_options_t entity_options[] = {
	/* base keys */
	{"BitmapPosition", S_P_UINT32},  // Bitmap position or Array Index correlation, This is used for conversion from Layout to Bitmap

	{"AllocatedNodeCount",S_P_UINT32}, // Selected,Allocated separate list is possible
		
	{"nodecount",S_P_UINT32},  // It is for SUM from child , And it shoud be "1"

	// topology based Node config
	{"AvailableNodeCount",S_P_UINT32},
	{"AvailableCpusCount",S_P_UINT16},
	{"SwitchesRequiredCount",S_P_UINT16},
	
	/* Parents aggregated keys */
	// topology based configuration
	
	{"AvailableSumNodesInLevel0", S_P_UINT32},  
	{"AvailableSumCpusInLevel0",S_P_UINT16}, 
	{"SwitchesRequiredInLevel0",S_P_UINT16},
	
	{"AvailableSumNodesInLevel1", S_P_UINT32}, 
	{"AvailableSumCpusInLevel1",S_P_UINT16},
	{"SwitchesRequiredInLevel1",S_P_UINT16},
	
	{"AvailableSumNodesInLevel2", S_P_UINT32},
	{"AvailableSumCpusInLevel2",S_P_UINT16},
	{"SwitchesRequiredInLevel2",S_P_UINT16},
	
	{"AvailableSumNodesInLevel3", S_P_UINT32},
	{"AvailableSumCpusInLevel3",S_P_UINT16},
	{"SwitchesRequiredInLevel3",S_P_UINT16},
	
	//Leaf switches to process
	{"SwitchToProcessInLevel0",S_P_UINT32},
	{"SwitchToProcessInLevel1",S_P_UINT32},
	{"SwitchToProcessInLevel2",S_P_UINT32},
	{"SwitchToProcessInLevel3",S_P_UINT32},
	
	{NULL}
        
};
s_p_options_t options[] = {
	{"Entity", S_P_EXPLINE, NULL, NULL, entity_options},
	{NULL}
};

const layouts_keyspec_t keyspec[] = {
	/* base keys */
   	{"BitmapPosition", L_T_UINT32},  // Bitmap position or Array Index correlation, This is used for conversion from Layout to Bitmap
	
	{"AllocatedNodeCount",L_T_UINT32}, 
	
	{"nodecount",L_T_UINT32},  // It is for SUM from child , And it shoud be "1"
	
	// topology based Node config
	{"AvailableNodeCount",L_T_UINT32}, 
	{"AvailableCpusCount",L_T_UINT16},
	{"SwitchesRequiredCount",L_T_UINT16},

	/* Parents aggregated keys */
	// topology based configuration
	{"AvailableSumNodesInLevel0", L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableNodeCount"},
	{"AvailableSumCpusInLevel0",L_T_UINT16, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableCpusCount"},
	{"SwitchesRequiredInLevel0",L_T_UINT16, KEYSPEC_UPDATE_CHILDREN_SUM, "SwitchesRequiredCount"},
	
	{"AvailableSumNodesInLevel1", L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumNodesInLevel0"}, 
	{"AvailableSumCpusInLevel1",L_T_UINT16, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumCpusInLevel0"},
	{"SwitchesRequiredInLevel1",L_T_UINT16,KEYSPEC_UPDATE_CHILDREN_SUM,"SwitchesRequiredInLevel0"},
	
	{"AvailableSumNodesInLevel2", L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumNodesInLevel1"},
	{"AvailableSumCpusInLevel2",L_T_UINT16, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumCpusInLevel1"},
	{"SwitchesRequiredInLevel2",L_T_UINT16,KEYSPEC_UPDATE_CHILDREN_SUM,"SwitchesRequiredInLevel1"},
	
	{"AvailableSumNodesInLevel3", L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumNodesInLevel2"},
	{"AvailableSumCpusInLevel3",L_T_UINT16, KEYSPEC_UPDATE_CHILDREN_SUM, "AvailableSumCpusInLevel2"},
	{"SwitchesRequiredInLevel3",L_T_UINT16,KEYSPEC_UPDATE_CHILDREN_SUM,"SwitchesRequiredInLevel2"},

	//Leaf switches to process
	
	{"SwitchToProcessInLevel0",L_T_UINT32, KEYSPEC_UPDATE_PARENTS_AVG,"SwitchToProcessInLevel1"},
	{"SwitchToProcessInLevel1",L_T_UINT32, KEYSPEC_UPDATE_PARENTS_AVG,"SwitchToProcessInLevel2"},
	{"SwitchToProcessInLevel2",L_T_UINT32, KEYSPEC_UPDATE_PARENTS_AVG,"SwitchToProcessInLevel3"},
	{"SwitchToProcessInLevel3",L_T_UINT32},
	
	/*{"SwitchToProcessInLevel0",L_T_UINT32},
	{"SwitchToProcessInLevel1",L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_AVG,"SwitchToProcessInLevel0"},
	{"SwitchToProcessInLevel2",L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_AVG,"SwitchToProcessInLevel1"},
	{"SwitchToProcessInLevel3",L_T_UINT32, KEYSPEC_UPDATE_CHILDREN_AVG,"SwitchToProcessInLevel2"},*/

	{NULL}
};

/* types allowed in the entity's "type" field */
const char* etypes[] = {
	"Switch",
	"Node",
	NULL
};

const layouts_plugin_spec_t plugin_spec = {
	options,
	keyspec,
	LAYOUT_STRUCT_TREE,
	etypes,
	true, /* if this evalued to true, keys inside plugin_keyspec present in
	       * plugin_options having corresponding types, are automatically
	       * handled by the layouts manager.
	       */
	true  /* if this evalued to true, keys updates trigger an automatic
	       * update of their entities neighborhoods based on their
	       * KEYSPEC_UPDATE_* set flags
	       */
};

/* manager is lock when this function is called */
/* disable this callback by setting it to NULL, warn: not every callback can
 * be desactivated this way */
int layouts_p_conf_done(
		xhash_t* entities, layout_t* layout, s_p_hashtbl_t* tbl)
{
	return 1;
}


/* disable this callback by setting it to NULL, warn: not every callback can
 * be desactivated this way */
void layouts_p_entity_parsing(
		entity_t* e, s_p_hashtbl_t* etbl, layout_t* layout)
{
}

/* manager is lock then this function is called */
/* disable this callback by setting it to NULL, warn: not every callback can
 * be desactivated this way */
int layouts_p_update_done(layout_t* layout, entity_t** e_array, int e_cnt)
{
	int i;
	debug3("layouts/cons_res_topology: receiving update callback for %d entities",
	       e_cnt);
	for (i=0; i < e_cnt; i++) {
		if (e_array[i] == NULL) {
			debug3("layouts/cons_res_topology: skipping update of nullified"
			       "entity[%d]", i);
		} else {
			debug3("layouts/cons_res_topology: updating entity[%d]=%s",
			       i, e_array[i]->name);
		}
	}
	return 1;
}

int init(void)
{
	return SLURM_SUCCESS;
}

int fini(void)
{
	return SLURM_SUCCESS;
}

