================================================================================
Verifcation components for DCache with coherency
================================================================================

This folder contains verification components for verifying the
**std_cache_subsystem** module with coherency additions.

-------------------------------------------------------------------------------
Components
-------------------------------------------------------------------------------


cva6 (cache_dummy)
===============================================================================
This is a version of the **cva6** core with only the cache subsystem remaining.
A test bench verifying the caches must drive the cache request ports.


std_cache_scoreboard
===============================================================================
This scoreboard receives transactions via a number of mailboxes and verifies
that the received transactions match what is expected. The scoreboard maintains
an internal model of the cache, `cache_status`, to be able to predict
transactions and verify against the real memory.

The scoreboard is activated by the task `run()` which in turn starts a number of
internal tasks that receives transactions.

* Cache load and store requests are received by `get_cache_msg()`, which then
  calls the `check_cache_msg()` task.
* Snoop transactions are received by the `check_snoop()` task.
* AMO requests are received by the `check_amo_msg` task.
* Management requests are received by the `check_mgmt_trans()` task.


check_cache_msg()
-------------------------------------------------------------------------------
This task receives dcache load and store requests and takes the following
actions:

#. The address is checked to determine which memory region the request targets.
#. For requests to a cached region, the cache model is queried to expect a hit
   or miss.
#. The expected AXI transactions are collected. If the received transactions
   don't match what is expected, or if no transaction is received before a
   timeout limit, an error is raised.
#. Under some circumstances, changes in the cache caused by other transactions
   (such as a `ClearInvalid` request to the snoop controller) causes the hit or
   miss subroutines to be run again to match the behaviour of the cache
   controller.
#. The message is passed on to the `update_cache_from_req` task.

The check_cache_msg task probes and waits for some internal signals via the
`gnt_vif` interface to be able to get a precise timing of the expected
transactions.


check_snoop()
-------------------------------------------------------------------------------
This task receives snoop requests and takes the following actions:

#. Check if the request targets a cacheable region. If so, sends the request to
   the `update_cache_from_snoop()` task.
#. Waits for the snoop response and compares it with an expected response.


update_cache_from_req(), update_cache_from_snoop()
-------------------------------------------------------------------------------
These tasks receive dcache and snoop requests requests respectively and take the
following actions:

#. Wait for cache access to be granted by probing internal signals.
#. Update the internal cache model based on current state of the cache and the
   received request.
#. Check that the contents of the internal cache model matches the cache in the
   DUT.

When checking the cache contents for a certain entry in the cache, all other
ways for the same index are also checked against the DUT. This is a trade-off
between a minimal check (only check the value of the expected way) and a maximal
check (check the contents of the entire cache on every access).


check_amo_msg()
-------------------------------------------------------------------------------
This task receives dcache AMO requests and takes the following actions:

#. The targeted cache entry is invalidated if it is a hit. If the cache entry is
   dirty, a write back transaction is expecetd.
#. The address is checked to determine which memory region the request targets.
#. The expected AXI transactions are collected. If the received transactions
   don't match what is expected, or if no transaction is received before a
   timeout limit, an error is raised.


check_mgmt_trans()
-------------------------------------------------------------------------------
This task receives dcache management requests. Currently only `flush` is
supported.

When a flush request is received, the following actions are taken:

#. The cache model is traversed. For each entry:
    #. If the entry is dirty, a write-back transaction is expected.
    #. If the entry is valid, wait for cache access to be granted (internal signal probed).
    #. Clear the cache entry.


std_dcache_checker
===============================================================================
TBD


amo_intf
===============================================================================

TBD


dcache_intf
===============================================================================
TBD

dcache_mgmt_intf
===============================================================================
TBD


dcache_sram_if
===============================================================================
TBD


dcache_gnt_if
===============================================================================
TBD


icache_intf
===============================================================================
TBD


sram_intf
===============================================================================
TBD


amo_driver
===============================================================================
TBD


amo_monitor
===============================================================================
TBD


dcache_driver
===============================================================================
TBD


dcache_monitor
===============================================================================
TBD


icache_driver
===============================================================================
TBD


icache_monitor
===============================================================================
TBD


dcache_mgmt_driver
===============================================================================
TBD


dcache_mgmt_monitor
===============================================================================
TBD




