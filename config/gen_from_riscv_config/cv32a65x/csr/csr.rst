.. ..::

   Copyright (c) 2024 OpenHW Group
   Copyright (c) 2024 Thales
   SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
   Author: Abdessamii Oukalrazqou

===
csr
===

Conventions
-----------

In the subsequent sections, register fields are labeled with one of the
following abbreviations:

- WPRI (Writes Preserve Values, Reads Ignore Values): read/write field
  reserved for future use.  For forward compatibility, implementations
  that do not furnish these fields must make them read-only zero.
- WLRL (Write/Read Only Legal Values): read/write CSR field that
  specifies behavior for only a subset of possible bit encodings, with
  other bit encodings reserved.
- WARL (Write Any Values, Reads Legal Values): read/write CSR fields
  which are only defined for a subset of bit encodings, but allow any
  value to be written while guaranteeing to return a legal value
  whenever read.
- ROCST (Read-Only Constant): A special case of WARL field which admits
  only one legal value, and therefore, behaves as a constant field that
  silently ignores writes.
- ROVAR (Read-Only Variable): A special case of WARL field which can
  take   multiple legal values but cannot be modified by software and
  depends only on   the architectural state of the hart.

In particular, a register that is not internally divided into multiple
fields can be considered as containing a single field of XLEN bits. This
allows to clearly represent read-write registers holding a single legal
value (typically zero).

Register Summary
----------------

+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| Address     | Register Name       | Privilege   | Description                                                                                        |
+=============+=====================+=============+====================================================================================================+
| 0x300       | MSTATUS_            | MRW         | The mstatus register keeps track of and controls the hart's current operating state.               |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x301       | MISA_               | MRO         | misa is a read-write register reporting the ISA supported by the hart.                             |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x304       | MIE_                | MRW         | The mie register is an MXLEN-bit read/write register containing interrupt enable bits.             |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x305       | MTVEC_              | MRW         | MXLEN-bit read/write register that holds trap vector configuration.                                |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x310       | MSTATUSH_           | MRO         | The mstatush register keeps track of and controls the hart’s current operating state.              |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x323-0x33f | MHPMEVENT[3-31]_    | MRO         | The mhpmevent is a MXLEN-bit event register which controls mhpmcounter3.                           |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x340       | MSCRATCH_           | MRW         | The mscratch register is an MXLEN-bit read/write register dedicated for use by machine mode.       |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x341       | MEPC_               | MRW         | The mepc is a warl register that must be able to hold all valid physical and virtual addresses.    |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x342       | MCAUSE_             | MRW         | The mcause register stores the information regarding the trap.                                     |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x343       | MTVAL_              | MRO         | The mtval is a warl register that holds the address of the instruction which caused the exception. |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x344       | MIP_                | MRO         | The mip register is an MXLEN-bit read/write register containing information on pending interrupts. |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x3a0-0x3a3 | PMPCFG[0-3]_        | MRW         | PMP configuration register                                                                         |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0x3b0-0x3bf | PMPADDR[0-15]_      | MRW         | Physical memory protection address register                                                        |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb00       | MCYCLE_             | MRW         | Counts the number of clock cycles executed from an arbitrary point in time.                        |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb02       | MINSTRET_           | MRW         | Counts the number of instructions completed from an arbitrary point in time.                       |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb03-0xb1f | MHPMCOUNTER[3-31]_  | MRO         | The mhpmcounter is a 64-bit counter. Returns lower 32 bits in RV32I mode.                          |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb80       | MCYCLEH_            | MRW         | upper 32 bits of mcycle                                                                            |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb82       | MINSTRETH_          | MRW         | Upper 32 bits of minstret.                                                                         |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xb83-0xb9f | MHPMCOUNTER[3-31]H_ | MRO         | The mhpmcounterh returns the upper half word in RV32I systems.                                     |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xf11       | MVENDORID_          | MRO         | 32-bit read-only register providing the JEDEC manufacturer ID of the provider of the core.         |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xf12       | MARCHID_            | MRO         | MXLEN-bit read-only register encoding the base microarchitecture of the hart.                      |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xf13       | MIMPID_             | MRO         | Provides a unique encoding of the version of the processor implementation.                         |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xf14       | MHARTID_            | MRO         | MXLEN-bit read-only register containing the integer ID of the hardware thread running the code.    |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+
| 0xf15       | MCONFIGPTR_         | MRO         | MXLEN-bit read-only register that holds the physical address of a configuration data structure.    |
+-------------+---------------------+-------------+----------------------------------------------------------------------------------------------------+

Register Description
--------------------
MSTATUS
-------

:Address: 0x300
:Reset Value: 0x00001800
:Privilege: MRW
:Description: The mstatus register keeps track of and controls the
   hart's current operating state.

+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| Bits    | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                                     |
+=========+==============+===============+========+================+=================================================================================================================+
| 0       | UIE          | 0x0           | ROCST  |                | Stores the state of the user mode interrupts.                                                                   |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 1       | SIE          | 0x0           | ROCST  |                | Stores the state of the supervisor mode interrupts.                                                             |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 2       | RESERVED_2   | 0x0           | WPRI   |                | Reserved                                                                                                        |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 3       | MIE          | 0x0           | WLRL   | [0 , 1]        | Stores the state of the machine mode interrupts.                                                                |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 4       | UPIE         | 0x0           | ROCST  |                | Stores the state of the user mode interrupts prior to the trap.                                                 |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 5       | SPIE         | 0x0           | ROCST  |                | Stores the state of the supervisor mode interrupts prior to the trap.                                           |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 6       | UBE          | 0x0           | ROCST  |                | control the endianness of memory accesses other than instruction fetches for user mode                          |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 7       | MPIE         | 0x0           | WLRL   | [0 , 1]        | Stores the state of the machine mode interrupts prior to the trap.                                              |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 8       | SPP          | 0x0           | ROCST  |                | Stores the previous priority mode for supervisor.                                                               |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| [10:9]  | RESERVED_9   | 0x0           | WPRI   |                | Reserved                                                                                                        |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| [12:11] | MPP          | 0x3           | WARL   | [0x3]          | Stores the previous priority mode for machine.                                                                  |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| [14:13] | FS           | 0x0           | ROCST  |                | Encodes the status of the floating-point unit, including the CSR fcsr and floating-point data registers.        |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| [16:15] | XS           | 0x0           | ROCST  |                | Encodes the status of additional user-mode extensions and associated state.                                     |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 17      | MPRV         | 0x0           | ROCST  |                | Modifies the privilege level at which loads and stores execute in all privilege modes.                          |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 18      | SUM          | 0x0           | ROCST  |                | Modifies the privilege with which S-mode loads and stores access virtual memory.                                |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 19      | MXR          | 0x0           | ROCST  |                | Modifies the privilege with which loads access virtual memory.                                                  |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 20      | TVM          | 0x0           | ROCST  |                | Supports intercepting supervisor virtual-memory management operations.                                          |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 21      | TW           | 0x0           | ROCST  |                | Supports intercepting the WFI instruction.                                                                      |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 22      | TSR          | 0x0           | ROCST  |                | Supports intercepting the supervisor exception return instruction.                                              |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 23      | SPELP        | 0x0           | ROCST  |                | Supervisor mode previous expected-landing-pad (ELP) state.                                                      |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| [30:24] | RESERVED_24  | 0x0           | WPRI   |                | Reserved                                                                                                        |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+
| 31      | SD           | 0x0           | ROCST  |                | Read-only bit that summarizes whether either the FS field or XS field signals the presence of some dirty state. |
+---------+--------------+---------------+--------+----------------+-----------------------------------------------------------------------------------------------------------------+

MISA
----

:Address: 0x301
:Reset Value: 0x40001106
:Privilege: MRO
:Description: misa is a read-write register reporting the ISA supported
   by the hart.

+---------+--------------+---------------+--------+----------------+------------------------------------------------------------------------------------------------+
| Bits    | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                    |
+=========+==============+===============+========+================+================================================================================================+
| [25:0]  | EXTENSIONS   | 0x1106        | ROCST  | 0x1106         | Encodes the presence of the standard extensions, with a single bit per letter of the alphabet. |
+---------+--------------+---------------+--------+----------------+------------------------------------------------------------------------------------------------+
| [29:26] | RESERVED_26  | 0x0           | WPRI   |                | Reserved                                                                                       |
+---------+--------------+---------------+--------+----------------+------------------------------------------------------------------------------------------------+
| [31:30] | MXL          | 0x1           | ROCST  | 0x1            | Encodes the native base integer ISA width.                                                     |
+---------+--------------+---------------+--------+----------------+------------------------------------------------------------------------------------------------+

MIE
---

:Address: 0x304
:Reset Value: 0x00000000
:Privilege: MRW
:Description: The mie register is an MXLEN-bit read/write register
   containing interrupt enable bits.

+---------+--------------+---------------+--------+----------------+---------------------------------------+
| Bits    | Field Name   | Reset Value   | Type   | Legal Values   | Description                           |
+=========+==============+===============+========+================+=======================================+
| 0       | USIE         | 0x0           | ROCST  |                | User Software Interrupt enable.       |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 1       | SSIE         | 0x0           | ROCST  |                | Supervisor Software Interrupt enable. |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 2       | VSSIE        | 0x0           | ROCST  |                | VS-level Software Interrupt enable.   |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 3       | MSIE         | 0x0           | ROCST  |                | Machine Software Interrupt enable.    |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 4       | UTIE         | 0x0           | ROCST  |                | User Timer Interrupt enable.          |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 5       | STIE         | 0x0           | ROCST  |                | Supervisor Timer Interrupt enable.    |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 6       | VSTIE        | 0x0           | ROCST  |                | VS-level Timer Interrupt enable.      |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 7       | MTIE         | 0x0           | WLRL   | [0 , 1]        | Machine Timer Interrupt enable.       |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 8       | UEIE         | 0x0           | ROCST  |                | User External Interrupt enable.       |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 9       | SEIE         | 0x0           | ROCST  |                | Supervisor External Interrupt enable. |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 10      | VSEIE        | 0x0           | ROCST  |                | VS-level External Interrupt enable.   |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 11      | MEIE         | 0x0           | WLRL   | [0 , 1]        | Machine External Interrupt enable.    |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| 12      | SGEIE        | 0x0           | ROCST  |                | HS-level External Interrupt enable.   |
+---------+--------------+---------------+--------+----------------+---------------------------------------+
| [31:13] | RESERVED_13  | 0x0           | WPRI   |                | Reserved                              |
+---------+--------------+---------------+--------+----------------+---------------------------------------+

MTVEC
-----

:Address: 0x305
:Reset Value: 0x80010000
:Privilege: MRW
:Description: MXLEN-bit read/write register that holds trap vector
   configuration.

+--------+--------------+---------------+--------+-----------------------------------+----------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values                      | Description          |
+========+==============+===============+========+===================================+======================+
| [1:0]  | MODE         | 0x0           | WARL   | [0x0]                             | Vector mode.         |
+--------+--------------+---------------+--------+-----------------------------------+----------------------+
| [31:2] | BASE         | 0x20004000    | WARL   | masked: & 0x3FFFFFFE | 0x00000000 | Vector base address. |
+--------+--------------+---------------+--------+-----------------------------------+----------------------+

MSTATUSH
--------

:Address: 0x310
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mstatush register keeps track of and controls the
   hart’s current operating state.

+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| Bits    | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                  |
+=========+==============+===============+========+================+==============================================================================================+
| [3:0]   | RESERVED_0   | 0x0           | WPRI   |                | Reserved                                                                                     |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 4       | SBE          | 0x0           | ROCST  |                | control the endianness of memory accesses other than instruction fetches for supervisor mode |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 5       | MBE          | 0x0           | ROCST  |                | control the endianness of memory accesses other than instruction fetches for machine mode    |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 6       | GVA          | 0x0           | ROCST  |                | Stores the state of the supervisor mode interrupts.                                          |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 7       | MPV          | 0x0           | ROCST  |                | Stores the state of the user mode interrupts.                                                |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 8       | RESERVED_8   | 0x0           | WPRI   |                | Reserved                                                                                     |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| 9       | MPELP        | 0x0           | ROCST  |                | Machine mode previous expected-landing-pad (ELP) state.                                      |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+
| [31:10] | RESERVED_10  | 0x0           | WPRI   |                | Reserved                                                                                     |
+---------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------+

MHPMEVENT[3-31]
---------------

:Address: 0x323-0x33f
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mhpmevent is a MXLEN-bit event register which controls
   mhpmcounter3.

+--------+--------------+---------------+--------+----------------+--------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                              |
+========+==============+===============+========+================+==========================================================================+
| [31:0] | MHPMEVENT[I] | 0x00000000    | ROCST  | 0x00000000     | The mhpmevent is a MXLEN-bit event register which controls mhpmcounter3. |
+--------+--------------+---------------+--------+----------------+--------------------------------------------------------------------------+

MSCRATCH
--------

:Address: 0x340
:Reset Value: 0x00000000
:Privilege: MRW
:Description: The mscratch register is an MXLEN-bit read/write register
   dedicated for use by machine mode.

+--------+--------------+---------------+--------+---------------------------+----------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                                                                                  |
+========+==============+===============+========+===========================+==============================================================================================+
| [31:0] | MSCRATCH     | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | The mscratch register is an MXLEN-bit read/write register dedicated for use by machine mode. |
+--------+--------------+---------------+--------+---------------------------+----------------------------------------------------------------------------------------------+

MEPC
----

:Address: 0x341
:Reset Value: 0x00000000
:Privilege: MRW
:Description: The mepc is a warl register that must be able to hold all
   valid physical and virtual addresses.

+--------+--------------+---------------+--------+---------------------------+-------------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                                                                                     |
+========+==============+===============+========+===========================+=================================================================================================+
| [31:0] | MEPC         | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | The mepc is a warl register that must be able to hold all valid physical and virtual addresses. |
+--------+--------------+---------------+--------+---------------------------+-------------------------------------------------------------------------------------------------+

MCAUSE
------

:Address: 0x342
:Reset Value: 0x00000000
:Privilege: MRW
:Description: The mcause register stores the information regarding the
   trap.

+--------+----------------+---------------+--------+----------------+-----------------------------------------------------+
| Bits   | Field Name     | Reset Value   | Type   | Legal Values   | Description                                         |
+========+================+===============+========+================+=====================================================+
| [30:0] | EXCEPTION_CODE | 0x0           | WLRL   | [0 , 15]       | Encodes the exception code.                         |
+--------+----------------+---------------+--------+----------------+-----------------------------------------------------+
| 31     | INTERRUPT      | 0x0           | WLRL   | [0x0 , 0x1]    | Indicates whether the trap was due to an interrupt. |
+--------+----------------+---------------+--------+----------------+-----------------------------------------------------+

MTVAL
-----

:Address: 0x343
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mtval is a warl register that holds the address of the
   instruction which caused the exception.

+--------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                        |
+========+==============+===============+========+================+====================================================================================================+
| [31:0] | MTVAL        | 0x00000000    | ROCST  | 0x00000000     | The mtval is a warl register that holds the address of the instruction which caused the exception. |
+--------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------------------------------+

MIP
---

:Address: 0x344
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mip register is an MXLEN-bit read/write register
   containing information on pending interrupts.

+---------+--------------+---------------+--------+----------------+----------------------------------------+
| Bits    | Field Name   | Reset Value   | Type   | Legal Values   | Description                            |
+=========+==============+===============+========+================+========================================+
| 0       | USIP         | 0x0           | ROCST  |                | User Software Interrupt Pending.       |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 1       | SSIP         | 0x0           | ROCST  |                | Supervisor Software Interrupt Pending. |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 2       | VSSIP        | 0x0           | ROCST  |                | VS-level Software Interrupt Pending.   |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 3       | MSIP         | 0x0           | ROCST  |                | Machine Software Interrupt Pending.    |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 4       | UTIP         | 0x0           | ROCST  |                | User Timer Interrupt Pending.          |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 5       | STIP         | 0x0           | ROCST  |                | Supervisor Timer Interrupt Pending.    |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 6       | VSTIP        | 0x0           | ROCST  |                | VS-level Timer Interrupt Pending.      |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 7       | MTIP         | 0x0           | ROVAR  | [0 , 1]        | Machine Timer Interrupt Pending.       |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 8       | UEIP         | 0x0           | ROCST  |                | User External Interrupt Pending.       |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 9       | SEIP         | 0x0           | ROCST  |                | Supervisor External Interrupt Pending. |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 10      | VSEIP        | 0x0           | ROCST  |                | VS-level External Interrupt Pending.   |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 11      | MEIP         | 0x0           | ROVAR  | [0 , 1]        | Machine External Interrupt Pending.    |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| 12      | SGEIP        | 0x0           | ROCST  |                | HS-level External Interrupt Pending.   |
+---------+--------------+---------------+--------+----------------+----------------------------------------+
| [31:13] | RESERVED_13  | 0x0           | WPRI   |                | Reserved                               |
+---------+--------------+---------------+--------+----------------+----------------------------------------+

PMPCFG[0-3]
-----------

:Address: 0x3a0-0x3a3
:Reset Value: 0x00000000
:Privilege: MRW
:Description: PMP configuration register

+---------+-----------------+---------------+--------+----------------+------------------------+
| Bits    | Field Name      | Reset Value   | Type   | Legal Values   | Description            |
+=========+=================+===============+========+================+========================+
| [7:0]   | PMP[I*4 + 0]CFG | 0x0           | WARL   | [0x00:0xFF]    | pmp configuration bits |
+---------+-----------------+---------------+--------+----------------+------------------------+
| [15:8]  | PMP[I*4 + 1]CFG | 0x0           | WARL   | [0x00:0xFF]    | pmp configuration bits |
+---------+-----------------+---------------+--------+----------------+------------------------+
| [23:16] | PMP[I*4 + 2]CFG | 0x0           | WARL   | [0x00:0xFF]    | pmp configuration bits |
+---------+-----------------+---------------+--------+----------------+------------------------+
| [31:24] | PMP[I*4 + 3]CFG | 0x0           | WARL   | [0x00:0xFF]    | pmp configuration bits |
+---------+-----------------+---------------+--------+----------------+------------------------+

PMPADDR[0-15]
-------------

:Address: 0x3b0-0x3bf
:Reset Value: 0x00000000
:Privilege: MRW
:Description: Physical memory protection address register

+--------+--------------+---------------+--------+---------------------------+---------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                                 |
+========+==============+===============+========+===========================+=============================================+
| [31:0] | PMPADDR[I]   | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | Physical memory protection address register |
+--------+--------------+---------------+--------+---------------------------+---------------------------------------------+

MCYCLE
------

:Address: 0xb00
:Reset Value: 0x00000000
:Privilege: MRW
:Description: Counts the number of clock cycles executed from an
   arbitrary point in time.

+--------+--------------+---------------+--------+---------------------------+-----------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                                                                 |
+========+==============+===============+========+===========================+=============================================================================+
| [31:0] | MCYCLE       | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | Counts the number of clock cycles executed from an arbitrary point in time. |
+--------+--------------+---------------+--------+---------------------------+-----------------------------------------------------------------------------+

MINSTRET
--------

:Address: 0xb02
:Reset Value: 0x00000000
:Privilege: MRW
:Description: Counts the number of instructions completed from an
   arbitrary point in time.

+--------+--------------+---------------+--------+---------------------------+------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                                                                  |
+========+==============+===============+========+===========================+==============================================================================+
| [31:0] | MINSTRET     | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | Counts the number of instructions completed from an arbitrary point in time. |
+--------+--------------+---------------+--------+---------------------------+------------------------------------------------------------------------------+

MHPMCOUNTER[3-31]
-----------------

:Address: 0xb03-0xb1f
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mhpmcounter is a 64-bit counter. Returns lower 32 bits
   in RV32I mode.

+--------+----------------+---------------+--------+----------------+---------------------------------------------------------------------------+
| Bits   | Field Name     | Reset Value   | Type   | Legal Values   | Description                                                               |
+========+================+===============+========+================+===========================================================================+
| [31:0] | MHPMCOUNTER[I] | 0x00000000    | ROCST  | 0x00000000     | The mhpmcounter is a 64-bit counter. Returns lower 32 bits in RV32I mode. |
+--------+----------------+---------------+--------+----------------+---------------------------------------------------------------------------+

MCYCLEH
-------

:Address: 0xb80
:Reset Value: 0x00000000
:Privilege: MRW
:Description: upper 32 bits of mcycle

+--------+--------------+---------------+--------+---------------------------+-------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description             |
+========+==============+===============+========+===========================+=========================+
| [31:0] | MCYCLEH      | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | upper 32 bits of mcycle |
+--------+--------------+---------------+--------+---------------------------+-------------------------+

MINSTRETH
---------

:Address: 0xb82
:Reset Value: 0x00000000
:Privilege: MRW
:Description: Upper 32 bits of minstret.

+--------+--------------+---------------+--------+---------------------------+----------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values              | Description                |
+========+==============+===============+========+===========================+============================+
| [31:0] | MINSTRETH    | 0x00000000    | WARL   | [0x00000000 , 0xFFFFFFFF] | Upper 32 bits of minstret. |
+--------+--------------+---------------+--------+---------------------------+----------------------------+

MHPMCOUNTER[3-31]H
------------------

:Address: 0xb83-0xb9f
:Reset Value: 0x00000000
:Privilege: MRO
:Description: The mhpmcounterh returns the upper half word in RV32I
   systems.

+--------+-----------------+---------------+--------+----------------+----------------------------------------------------------------+
| Bits   | Field Name      | Reset Value   | Type   | Legal Values   | Description                                                    |
+========+=================+===============+========+================+================================================================+
| [31:0] | MHPMCOUNTER[I]H | 0x00000000    | ROCST  | 0x00000000     | The mhpmcounterh returns the upper half word in RV32I systems. |
+--------+-----------------+---------------+--------+----------------+----------------------------------------------------------------+

MVENDORID
---------

:Address: 0xf11
:Reset Value: 0x00000602
:Privilege: MRO
:Description: 32-bit read-only register providing the JEDEC manufacturer
   ID of the provider of the core.

+--------+--------------+---------------+--------+----------------+--------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                |
+========+==============+===============+========+================+============================================================================================+
| [31:0] | MVENDORID    | 0x00000602    | ROCST  | 0x00000602     | 32-bit read-only register providing the JEDEC manufacturer ID of the provider of the core. |
+--------+--------------+---------------+--------+----------------+--------------------------------------------------------------------------------------------+

MARCHID
-------

:Address: 0xf12
:Reset Value: 0x00000003
:Privilege: MRO
:Description: MXLEN-bit read-only register encoding the base
   microarchitecture of the hart.

+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                   |
+========+==============+===============+========+================+===============================================================================+
| [31:0] | MARCHID      | 0x00000003    | ROCST  | 0x00000003     | MXLEN-bit read-only register encoding the base microarchitecture of the hart. |
+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------+

MIMPID
------

:Address: 0xf13
:Reset Value: 0x00000000
:Privilege: MRO
:Description: Provides a unique encoding of the version of the processor
   implementation.

+--------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                |
+========+==============+===============+========+================+============================================================================+
| [31:0] | MIMPID       | 0x00000000    | ROCST  | 0x00000000     | Provides a unique encoding of the version of the processor implementation. |
+--------+--------------+---------------+--------+----------------+----------------------------------------------------------------------------+

MHARTID
-------

:Address: 0xf14
:Reset Value: 0x00000000
:Privilege: MRO
:Description: MXLEN-bit read-only register containing the integer ID of
   the hardware thread running the code.

+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                     |
+========+==============+===============+========+================+=================================================================================================+
| [31:0] | MHARTID      | 0x00000000    | ROCST  | 0x00000000     | MXLEN-bit read-only register containing the integer ID of the hardware thread running the code. |
+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------------------------+

MCONFIGPTR
----------

:Address: 0xf15
:Reset Value: 0x00000000
:Privilege: MRO
:Description: MXLEN-bit read-only register that holds the physical
   address of a configuration data structure.

+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                                                                                     |
+========+==============+===============+========+================+=================================================================================================+
| [31:0] | MCONFIGPTR   | 0x00000000    | ROCST  | 0x00000000     | MXLEN-bit read-only register that holds the physical address of a configuration data structure. |
+--------+--------------+---------------+--------+----------------+-------------------------------------------------------------------------------------------------+

