# Copyright 2024 Thales DIS France SAS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Original Author: Oukalrazqou Abdessamii

""" Module is used to gather all utils and function to generate the csr and isa documents"""

import io
import os
import re
import yaml
import rstcloth
import libs.isa_updater
import libs.csr_updater
import libs.csr_factorizer
from rstcloth import RstCloth
from mdutils.mdutils import MdUtils
from libs.isa_updater import isa_filter
from libs.csr_updater import csr_formatter
from libs.csr_factorizer import factorizer

pattern_warl = (
    r"\b(?:warl|wlrl|ro_constant|ro_variable)\b"  # pattern to detect warl in field
)
pattern_legal_dict = r"\[(0x[0-9A-Fa-f]+)(.*?(0x[0-9A-Fa-f]+))?\]"  # pattern to detect if warl field is dict
pattern_legal_list = r"\[(0x[0-9A-Fa-f]+)(.*?(0x[0-9A-Fa-f]+))?\]"  # pattern to detect if warl field is a list
Factorizer_pattern = r".*(\d).*"  # pattern to detect factorized fields


class DocumentClass:
    """Document class"""

    def __init__(self, name):
        self.name = name
        self.memoryMapList = []

    def addMemoryMap(self, memoryMap):
        self.memoryMapList.append(memoryMap)


class MemoryMapClass:
    """memory map class"""

    def __init__(self, name):
        self.name = name
        self.addressBlockList = []

    def addAddressBlock(self, addressBlock):
        self.addressBlockList.append(addressBlock)


class AddressBlockClass:
    """address block class"""

    def __init__(self, name):
        self.name = name
        self.registerList = []
        self.suffix = ""

    def addRegister(self, reg):
        assert isinstance(reg, RegisterClass)
        self.registerList.append(reg)

    def setRegisterList(self, registerList):
        self.registerList = registerList

    def returnAsString(self):
        raise NotImplementedError(
            "method returnAsString() is virtual and must be overridden."
        )


class RegisterClass:
    """register class"""

    def __init__(
        self, name, address, resetValue, size, access, desc, RV32, RV64, field
    ):
        self.name = name
        self.address = address
        self.resetValue = resetValue
        self.size = size
        self.access = access
        self.desc = desc
        self.RV32 = RV32
        self.RV64 = RV64
        self.field = field


class Field:
    """field class"""

    def __init__(
        self,
        name,
        bitlegal,
        fieldreset,
        bitmsb,
        bitlsb,
        bitWidth,
        fieldDesc,
        fieldaccess,
        andMask=None,
        orMask=None,
    ):
        self.name = name
        self.bitlegal = bitlegal
        self.fieldreset = fieldreset
        self.bitmsb = bitmsb
        self.bitlsb = bitlsb
        self.bitWidth = bitWidth
        self.fieldDesc = fieldDesc
        self.fieldaccess = fieldaccess
        self.andMask = andMask
        self.orMask = orMask


# --------------------------------------------------------------#
class ISAdocumentClass:
    """ISA document class"""

    def __init__(self, name):
        self.name = name
        self.instructions = []

    def addInstructionMapBlock(self, InstructionMap):
        self.instructions.append(InstructionMap)


class InstructionMapClass:
    """ISA instruction map class"""

    def __init__(self, name):
        self.name = name
        self.InstructionBlockList = []

    def addInstructionBlock(self, InstructionBlock):
        self.InstructionBlockList.append(InstructionBlock)


class Instruction:
    """ISA instruction  class"""

    def __init__(
        self,
        key,
        Extension_Name,
        descr,
        OperationName,
        Name,
        Format,
        Description,
        pseudocode,
        invalid_values,
        exception_raised,
    ):
        self.key = key
        self.Extension_Name = Extension_Name
        self.descr = descr
        self.OperationName = OperationName
        self.Name = Name
        self.Format = Format
        self.Description = Description
        self.invalid_values = invalid_values
        self.pseudocode = pseudocode
        self.exception_raised = exception_raised


class InstructionBlockClass:
    """ISA instruction block class"""

    def __init__(self, name):
        self.name = name
        self.Instructionlist = []
        self.suffix = ""

    def addInstruction(self, Inst):
        assert isinstance(Inst, Instruction)
        self.Instructionlist.append(Inst)

    def setInstructionList(self, Instructionlist):
        self.Instructionlist = Instructionlist

    def returnAsString(self):
        raise NotImplementedError(
            "method returnAsString() is virtual and must be overridden."
        )


class RstAddressBlock(AddressBlockClass):
    """Generates a ReStructuredText file from a IP-XACT register description"""

    def __init__(self, name):
        super().__init__("csr")
        self.name = name
        self.registerList = []
        self.suffix = ".rst"

    def sort_address(self):
        for reg in self.registerList:
            if "-" in reg.address:
                start, end = reg.address.split("-")
                return int(start, 16), int(end, 16)
            return int(reg.address, 16), int(reg.address, 16)

    def get_access(self, reg):
        register_access = "RO"
        for field in reg.field:
            if field.fieldaccess == "WARL" or field.fieldaccess == "WLRL":
                register_access = "RW"
                break
        return register_access

    def change_access(self, field):
        switcher = {
            "RO_CONSTANT": "ROCST",
            "RO_VARIABLE": "ROVAR",
        }
        return switcher.get(field.fieldaccess, field.fieldaccess)

    def returnAsString(self):
        registerlist = sorted(self.registerList, key=lambda reg: reg.address)
        r = RstCloth(io.StringIO())  # with default parameter, sys.stdout is used
        regNameList = [reg.name for reg in registerlist]
        regAddressList = [reg.address for reg in registerlist]
        regPrivModeList = [reg.access for reg in registerlist]
        regAccessList = [self.get_access(reg) for reg in registerlist]
        regDescrList = [reg.desc for reg in registerlist]
        regRV32List = [reg.RV32 for reg in registerlist]
        regRV64List = [reg.RV64 for reg in registerlist]
        r.directive(
            "..",
            content=[
                "Copyright (c) 2024 OpenHW Group",
                "Copyright (c) 2024 Thales",
                "SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1",
                "Author: Abdessamii Oukalrazqou",
            ],
        )
        r.title(self.name)  # Use the name of the addressBlock as title
        r.newline()
        r.h2("Conventions")
        r.newline()
        r.content(
            """In the subsequent sections, register fields are labeled with one of the
following abbreviations:
"""
        )
        r.newline()
        r.li(
            """WPRI (Writes Preserve Values, Reads Ignore Values): read/write field reserved
for future use.  For forward compatibility, implementations that do not
furnish these fields must make them read-only zero."""
        )
        r.li(
            """WLRL (Write/Read Only Legal Values): read/write CSR field that specifies
behavior for only a subset of possible bit encodings, with other bit encodings
reserved."""
        )
        r.li(
            """WARL (Write Any Values, Reads Legal Values): read/write CSR fields which are
only defined for a subset of bit encodings, but allow any value to be written
while guaranteeing to return a legal value whenever read."""
        )
        r.li(
            """ROCST (Read-Only Constant): A special case of WARL field which admits only one
legal value, and therefore, behaves as a constant field that silently ignores
writes."""
        )
        r.li(
            """ROVAR (Read-Only Variable): A special case of WARL field which can take
  multiple legal values but cannot be modified by software and depends only on
  the architectural state of the hart."""
        )
        r.newline()
        r.content(
            """In particular, a register that is not internally divided
into multiple fields can be considered as containing a single field of XLEN bits.
This allows to clearly represent read-write registers holding a single legal value
(typically zero)."""
        )
        r.newline()
        r.h2("Register Summary")
        summary_table = []
        for i, _ in enumerate(regNameList):
            if regRV32List[i] | regRV64List[i]:
                summary_table.append(
                    [
                        regAddressList[i],
                        str(regNameList[i]).upper() + "_",
                        regPrivModeList[i] + regAccessList[i],
                        str(regDescrList[i]),
                    ]
                )
        r.table(
            header=["Address", "Register Name", "Privilege", "Description"],
            data=summary_table,
        )

        r.h2("Register Description")
        for reg in registerlist:
            if reg.RV32 | reg.RV64:
                reg_table = []
                r.h2(reg.name.upper())
                r.newline()
                r.field("Address", (reg.address))
                if reg.resetValue:
                    # display the resetvalue in hex notation in the full length of the register
                    r.field(
                        "Reset Value",
                        "0x" + f"{reg.resetValue[2:].zfill(int(reg.size/4))}",
                    )
                    # TODO FIXME: Add CSR privilege information to riscv-config schemas as implicit info.
                    # TODO FIXME: Handle the RO privilege of the Zicntr/Zihpm registers.
                    r.field("Privilege", reg.access + self.get_access(reg))
                    r.field("Description", reg.desc)
                for field in reg.field:
                    if field.bitWidth == 1:  # only one bit -> no range needed
                        bits = f"{field.bitlsb}"
                    else:
                        bits = f"[{field.bitmsb}:{field.bitlsb}]"
                    _line = [
                        bits,
                        field.name.upper(),
                        field.fieldreset,
                        self.change_access(field),
                        (
                            f"masked: & {field.andMask} | {field.orMask}"
                            if field.andMask and field.orMask
                            else field.bitlegal
                        ),
                    ]
                    _line.append(field.fieldDesc)
                    reg_table.append(_line)
                _headers = ["Bits", "Field Name", "Reset Value", "Type", "Legal Values"]
                _headers.append("Description")
                reg_table = sorted(
                    reg_table, key=lambda x: int(x[0].strip("[]").split(":")[0])
                )
                # table of the register
                r.table(header=_headers, data=reg_table)
        return r.data


class InstrstBlock(InstructionBlockClass):
    """Generates a ISA ReStructuredText file from RISC-V Config Yaml register description"""

    def __init__(self, name):
        super().__init__("isa")
        self.name = name
        self.Instructionlist = []
        self.suffix = ".rst"

    def returnAsString(self):
        r = rstcloth.RstCloth(
            io.StringIO()
        )  # with default parameter, sys.stdout is used
        InstrNameList = [reg.key for reg in self.Instructionlist]
        InstrDescrList = [reg.descr for reg in self.Instructionlist]
        InstrExtList = [reg.Extension_Name for reg in self.Instructionlist]
        r.directive(
            "..",
            content=[
                "Copyright (c) 2024 OpenHW Group",
                "Copyright (c) 2024 Thales",
                "SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1",
                "Author: Abdessamii Oukalrazqou",
            ],
        )
        r.title(self.name)  # Use the name of the addressBlock as title
        r.newline()
        r.h2("Instructions")
        summary_table = []
        for i, _ in enumerate(InstrNameList):
            summary_table.append(
                [
                    str(InstrExtList[i]),
                    str(InstrNameList[i]) + "_",
                    str(InstrDescrList[i]),
                ]
            )
        r.table(header=["Subset Name", "Name", "Description"], data=summary_table)
        for reg in self.Instructionlist:
            reg_table = []
            if len(reg.Name) > 0:
                _headers = [
                    "Name",
                    "Format",
                    "Pseudocode",
                    "Invalid_values",
                    "Exception_raised",
                    "Description",
                    "Op Name",
                ]
                r.h2(reg.key)
                r.newline()
                for fieldIndex in list(range(len(reg.Name))):
                    _line = [
                        reg.Name[fieldIndex],
                        reg.Format[fieldIndex],
                        reg.pseudocode[fieldIndex],
                        reg.invalid_values[fieldIndex],
                        reg.exception_raised[fieldIndex],
                        reg.Description[fieldIndex],
                    ]
                    _line.append(reg.OperationName[fieldIndex])
                    reg_table.append(_line)
                # table of the register
                r.table(header=_headers, data=reg_table)
        return r.data


class InstmdBlock(InstructionBlockClass):
    """Generates a  ISA Markdown file from a RISC Config Yaml register description"""

    def __init__(self, name):
        super().__init__("isa")
        self.name = name
        self.Instructionlist = []
        self.suffix = ".md"
        self.mdFile = MdUtils(file_name="none", title="")

    def returnAsString(self):
        InstrNameList = [reg.key for reg in self.Instructionlist]
        InstrDescrList = [reg.descr for reg in self.Instructionlist]
        InstrExtList = [reg.Extension_Name for reg in self.Instructionlist]
        licence = [
            "<!--Copyright (c) 2024 OpenHW Group",
            "Copyright (c) 2024 Thales",
            "SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1 ",
            "Author: Abdessamii Oukalrazqou",
            "-->",
        ]
        for l in licence:
            self.mdFile.write(l + "\n")
        self.mdFile.new_header(
            level=1, title=self.name
        )  # Use the name of the addressBlock as title
        self.mdFile.new_paragraph()
        self.mdFile.new_header(level=2, title="Instructions")

        # summary
        header = ["Subset Name", "Name ", "Description"]
        rows = []
        for i, _ in enumerate(InstrNameList):
            InstrDescrList[i] = str(InstrDescrList[i]).replace("\n", " ")
            rows.extend(
                [
                    str(InstrExtList[i]),
                    f"[{InstrNameList[i]}](#{InstrNameList[i]})",
                    str(InstrDescrList[i]),
                ]
            )
        self.mdFile.new_table(
            columns=len(header),
            rows=len(InstrNameList) + 1,  # header + data
            text=header + rows,
            text_align="left",
        )

        # all registers
        for reg in self.Instructionlist:
            if len(reg.Name) > 0:
                headers = [
                    "Name",
                    "Format",
                    "Pseudocode",
                    "Invalid_values",
                    "Exception_raised",
                    "Description",
                    "Op Name",
                ]
                self.returnMdRegDesc(reg.key)
                reg_table = []
                for fieldIndex in list(range(len(reg.Name))):
                    reg_table.append(reg.Name[fieldIndex].ljust(15))
                    reg.Format[fieldIndex] = (
                       reg.Format[fieldIndex]
                    )
                    reg_table.append(reg.Format[fieldIndex])
                    reg.pseudocode[fieldIndex] = str(
                        reg.pseudocode[fieldIndex]
                    ).replace("\n", " ")
                    reg_table.append(reg.pseudocode[fieldIndex])
                    reg_table.append(reg.invalid_values[fieldIndex])
                    reg.exception_raised[fieldIndex] = str(
                        reg.exception_raised[fieldIndex]
                    ).replace("\n", " ")
                    reg_table.append(reg.exception_raised[fieldIndex].ljust(40))
                    reg.Description[fieldIndex] = str(
                        reg.Description[fieldIndex]
                    ).replace("\n", " ")
                    reg_table.append(reg.Description[fieldIndex])
                    reg_table.append(reg.OperationName[fieldIndex])

                self.mdFile.new_table(
                    columns=len(headers),
                    rows=len(reg.Description) + 1,
                    text=headers + reg_table,
                    text_align="left",
                )
        return self.mdFile.file_data_text

    def returnMdRegDesc(self, name):
        self.mdFile.new_header(level=3, title=name)


class MdAddressBlock(AddressBlockClass):
    """Generates a CSR Markdown file from a RISC Config Yaml register description"""

    def __init__(self, name):
        super().__init__("csr")
        self.name = name
        self.registerList = []
        self.suffix = ".md"
        self.mdFile = MdUtils(file_name="none", title="")

    def parse_bits(self, bits):
        if ":" in bits:
            msb, lsb = map(int, bits.strip("[]").split(":")[0])
        else:
            msb = lsb = int(bits.strip("[]").split(":")[0])
        return msb, lsb

    def get_access(self, reg):
        register_access = "RO"
        for field in reg.field:
            if field.fieldaccess == "WARL":
                register_access = "RW"
                break
        return register_access

    def change_access(self, field):
        switcher = {
            "RO_CONSTANT": "ROCST",
            "RO_VARIABLE": "ROVAR",
        }
        return switcher.get(field.fieldaccess, field.fieldaccess)

    def returnAsString(self):
        registerlist = sorted(self.registerList, key=lambda reg: reg.address)
        regNameList = [reg.name for reg in registerlist if reg.RV32 | reg.RV64]
        regAddressList = [reg.address for reg in registerlist if reg.RV32 | reg.RV64]
        regDescrList = [reg.desc for reg in registerlist if reg.RV32 | reg.RV64]
        regAccessList = [
            self.get_access(reg) for reg in registerlist if reg.RV32 | reg.RV64
        ]
        regPrivModeList = [reg.access for reg in registerlist if reg.RV32 | reg.RV64]
        licence = [
            "<!--Copyright (c) 2024 OpenHW Group",
            "Copyright (c) 2024 Thales",
            "SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1 ",
            "Author: Abdessamii Oukalrazqou",
            "-->",
        ]
        for l in licence:
            self.mdFile.write(l + "\n")
        self.mdFile.new_header(
            level=1, title=self.name
        )  # Use the name of the addressBlock as title
        self.mdFile.new_paragraph()
        self.mdFile.new_header(level=2, title="Registers Summary")
        self.mdFile.new_paragraph()
        # summary
        header = ["Address", "Register Name", "Privilege", "Description"]
        rows = []
        for i, _ in enumerate(regNameList):
            regDescrList[i] = str(regDescrList[i]).replace("\n", " ")
            rows.extend(
                [
                    regAddressList[i],
                    f"[{regNameList[i].upper()}](#{regNameList[i].upper()})",
                    regPrivModeList[i] + regAccessList[i],
                    str(regDescrList[i]),
                ]
            )
        self.mdFile.new_table(
            columns=len(header),
            rows=len(regNameList) + 1,  # header + data
            text=header + rows,
            text_align="left",
        )
        # all registers
        self.mdFile.new_header(level=3, title="Registers Description")
        for reg in registerlist:
            if reg.RV64 | reg.RV32:
                self.returnMdRegDesc(
                    reg.name,
                    reg.address,
                    reg.resetValue,
                    reg.desc,
                    reg.access + self.get_access(reg),
                )
                reg_table = []
                _line = []
                for field in reg.field:
                    if field.bitWidth == 1:  # only one bit -> no range needed
                        bits = f"{field.bitlsb}"
                    else:
                        bits = f"[{field.bitmsb}:{field.bitlsb}]"
                    reg_table.append(
                        [
                            bits,
                            field.name.upper(),
                            field.fieldreset,
                            self.change_access(field),
                            field.bitlegal,
                            field.fieldDesc,
                        ]
                    )
                _headers = ["Bits", "Field Name", "Reset Value", "Type", "Legal Values"]
                _headers.append("Description")
                reg_table = sorted(
                    reg_table, key=lambda x: int(x[0].strip("[]").split(":")[0])
                )
                reg_table_flattened = [
                    item for sublist in reg_table for item in sublist
                ]
                self.mdFile.new_table(
                    columns=len(_headers),
                    rows=len(reg_table) + 1,
                    text=_headers + reg_table_flattened,
                    text_align="left",
                )

        return self.mdFile.file_data_text

    def returnMdRegDesc(self, name, address, resetValue, desc, access):
        self.mdFile.new_header(level=4, title=name.upper())
        self.mdFile.new_line("---")
        self.mdFile.new_line("**Address** " + str(address))
        if resetValue:
            # display the resetvalue in hex notation in the full length of the register
            self.mdFile.new_line("**Reset Value** " + resetValue)
        self.mdFile.new_line("**Privilege ** " + access)
        self.mdFile.new_line("**Description** " + desc)


# -----------------------------------------------------------------------------------------------------------------------#
class CsrParser:
    """parse CSR RISC-V config yaml file"""

    def __init__(self, srcFile, target, modiFile=None):
        self.srcFile = srcFile
        self.modiFile = modiFile
        self.target = target

    def returnRegister(
        self,
        regName,
        registerElem,
        regAddress,
        resetValue,
        size,
        access,
        regDesc,
        fields,
        RV32,
        RV64,
    ):
        fieldList = fields
        field = []
        if len(fieldList) > 0:
            for item in fieldList:
                andMask = None
                orMask = None
                if not isinstance(item, list):
                    fieldDesc = registerElem.get("rv32", "")[item].get(
                        "description", ""
                    )
                    bitWidth = (
                        int(registerElem.get("rv32", "")[item].get("msb", ""))
                        - int(registerElem.get("rv32", "")[item].get("lsb", ""))
                        + 1
                    )
                    bitmsb = int(registerElem.get("rv32", "")[item].get("msb", ""))
                    bitlsb = int(registerElem.get("rv32", "")[item].get("lsb", ""))
                    fieldreset = hex(
                        int(resetValue, 16) >> (bitlsb) & ((1 << ((bitWidth))) - 1)
                    )
                    fieldaccess = ""
                    legal = registerElem.get("rv32", "")[item].get("type", None)
                    print(legal)
                    if legal is None:
                        bitlegal = ""
                        fieldaccess = "ROCST"
                        fieldDesc = fieldDesc
                    else:
                        warl = re.findall(pattern_warl, str(legal.keys()))
                        if warl:
                            fieldaccess = warl[0].upper()
                            legal_2 = (
                                registerElem.get("rv32", "")[item]
                                .get("type", None)
                                .get(warl[0], None)
                            )
                            if legal_2 is None:
                                bitlegal = "No Legal values"
                            else:
                                if isinstance(legal_2, dict):
                                    pattern = r"([\w\[\]:]+)\s*(\w+)\s*(\[\s*((?:0x)?[0-9A-Fa-f]+)\s*\D+\s*(?:((?:0x)?[0-9A-Fa-f]+))?\s*])"
                                    matches = re.search(
                                        pattern, str(legal_2["legal"][0])
                                    )
                                    if matches:
                                        expr_type = str(matches.group(2))
                                        legal_value = matches.group(3)
                                        bitlegal = legal_value
                                        if expr_type == "bitmask":
                                            andMask = str(matches.group(4))
                                            orMask = str(matches.group(5))
                                elif isinstance(legal_2, list):
                                    pattern = r"\s*((?:0x)?[0-9A-Fa-f]+)\s*(.)\s*((?:0x)?[0-9A-Fa-f]+)\s*"
                                    matches = re.search(pattern, legal_2[0])
                                    if matches:
                                        legal_value = (
                                            f"[{matches.group(1)} , {matches.group(3)}]"
                                        )

                                        bitlegal = legal_value
                                else:
                                    legal_value = hex(legal_2)
                                    bitlegal = legal_value
                    pattern = r"((\D+)\d+(.*))-\d+"
                    match = re.match(pattern, regName)
                    if match:
                        match_field = re.search(Factorizer_pattern, str(item))
                        if match_field:
                            fieldName = re.sub(
                                match_field.group(1),
                                f"[i*4 + {match_field.group(1)}]",
                                item,
                            )
                    else:
                        fieldName = item
                    f = Field(
                        fieldName,
                        bitlegal,
                        fieldreset,
                        bitmsb,
                        bitlsb,
                        bitWidth,
                        fieldDesc,
                        fieldaccess,
                        andMask,
                        orMask,
                    )
                    field.append(f)
                elif isinstance(item, list):
                    for item_ in item:
                        fieldName = f"Reserved_{item_[0]}"
                        bitlsb = item_[0]
                        bitmsb = item_[len(item_) - 1]
                        legal = ""
                        fieldaccess = "WPRI"
                        bitWidth = int(item_[len(item_) - 1]) - int(item_[0]) + 1
                        fieldDesc = "Reserved"
                        bitlegal = legal
                        fieldreset = hex(
                            int(resetValue, 16) >> (bitlsb) & ((1 << ((bitWidth))) - 1)
                        )
                        f = Field(
                            fieldName,
                            bitlegal,
                            fieldreset,
                            bitmsb,
                            bitlsb,
                            bitWidth,
                            fieldDesc,
                            fieldaccess,
                        )
                        field.append(f)
        elif len(fieldList) == 0:
            pattern = r"(\D+)\[(\d+)\-\d+\](.*)"
            match = re.match(pattern, regName)
            if match:
                if len(match.group(3)) > 0:
                    name = f"{match.group(1)}[i]{match.group(3)}"
                    regDesc = re.sub(
                        match.group(1) + match.group(2) + match.group(3),
                        match.group(1) + match.group(3),
                        regDesc,
                    )
                else:
                    name = f"{match.group(1)}[i]"
                    regDesc = re.sub(
                        match.group(1) + match.group(2), match.group(1), regDesc
                    )
                fieldName = name
                fieldDesc = regDesc
            else:
                fieldName = regName
            bitmsb = registerElem.get("rv32", None).get("msb", None)
            bitlsb = registerElem.get("rv32", None).get("lsb", None)
            legal = registerElem.get("rv32", "").get("type", None)
            fieldaccess = ""
            andMask = None
            orMask = None
            if legal is None:
                bitlegal = ""
                bitmask = ""
                fieldaccess = "RO"
            else:
                warl = re.findall(pattern_warl, str(legal.keys()))
                if warl:
                    fieldaccess = warl[0].upper()
                    legal_2 = (
                        registerElem.get("rv32", "")
                        .get("type", None)
                        .get(warl[0], None)
                    )
                    if legal_2 is None:
                        bitlegal = "No Legal values"
                    else:
                        print(legal_2)
                        if isinstance(legal_2, dict):
                            pattern = r"([\w\[\]:]+\s*(\w+)\s*)(\[\s*((?:0x)?[0-9A-Fa-f]+)\s*\D+\s*(?:((?:0x)?[0-9A-Fa-f]+))?\s*])"
                            matches = re.search(pattern, str(legal_2["legal"][0]))
                            if matches:
                                legal_value = (
                                    f"[{matches.group(4)} , {matches.group(5)}]"
                                )
                                expr_type = str(matches.group(3))
                                mask = matches.group(5)
                                bitmask = mask
                                bitlegal = legal_value
                                if expr_type == "bitmask":
                                    andMask = str(matches.group(4))
                                    orMask = str(matches.group(5))
                        elif isinstance(legal_2, list):
                            pattern = r"([0-9A-Fa-f]+).*([0-9A-Fa-f]+)"
                            
                            matches = re.search(pattern, legal_2[0])
                            if matches:
                                legal_value = (
                                    f"[{matches.group(1)} , {matches.group(2)}]"
                                )
                                mask = matches.group(2)
                                bitmask = mask
                                bitlegal = legal_value
                        else:
                            bitmask = 0
                            bitlegal = "0x" + hex(legal_2)[2:].zfill(int(size / 4))
            fieldDesc = regDesc
            fieldreset = "0x" + hex(int(resetValue, 16))[2:].zfill(int(size / 4))
            if bitlsb is None:
                bitlsb = 0
            if bitmsb is None:
                bitmsb = 31
                bitWidth = ""
            else:
                bitWidth = int(bitmsb) + 1
            f = Field(
                fieldName,
                bitlegal,
                fieldreset,
                bitmsb,
                bitlsb,
                bitWidth,
                fieldDesc,
                fieldaccess,
            )
            field.append(f)
        reg = RegisterClass(
            regName, regAddress, resetValue, size, access, regDesc, RV32, RV64, field
        )
        return reg

    def returnDocument(self):
        with open(self.srcFile, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        data = csr_formatter(self.srcFile, self.modiFile)
        Registers = factorizer(data)
        docName = data["hart0"]
        d = DocumentClass(docName)
        m = MemoryMapClass(docName)
        a = AddressBlockClass("csr")
        for register in Registers:
            if isinstance(Registers.get(register, {}), dict):
                RegElement = Registers.get(register, {})
                regName = register
                regAddress = (
                    (RegElement.get("address", None))
                    if isinstance(RegElement.get("address", None), str)
                    else hex(RegElement.get("address", None))
                )
                reset = hex(RegElement.get("reset-val", ""))
                size = int(data["hart0"].get("supported_xlen", "")[0])
                access = RegElement.get("priv_mode", "")
                if Registers.get(register, {}).get("description", "") is not None:
                    desc = Registers.get(register, {}).get("description", "")
                else:
                    desc = ""
                RV32 = RegElement.get("rv32", "").get("accessible", [])
                RV64 = RegElement.get("rv64", "").get("accessible", [])
                if RV32:
                    fields = RegElement.get("rv32", "").get("fields", [])
                else:
                    fields = []
                r = self.returnRegister(
                    regName,
                    RegElement,
                    regAddress,
                    reset,
                    size,
                    access,
                    desc,
                    fields,
                    RV32,
                    RV64,
                )
                a.addRegister(r)
        m.addAddressBlock(a)
        d.addMemoryMap(m)

        return d


class IsaParser:
    """parse CSR risc-v config yaml file catch isa string"""

    def __init__(self, srcFile, templatefile, target, modiFile=None):
        self.srcFile = srcFile
        self.modiFile = modiFile
        self.templatefile = templatefile
        self.target = target

    def returnDocument(self):
        with open(self.srcFile, "r", encoding="utf-8") as file:
            yaml_data = yaml.safe_load(file)
        d = ISAdocumentClass("MAP")
        m = InstructionMapClass("ISA_B")
        a = InstructionBlockClass("isa")
        yaml_data = isa_filter(yaml_data, self.modiFile, self.templatefile)
        for key in yaml_data:
            Extension_Name = yaml_data[key].get("Subset_Name", None)
            Descr = yaml_data[key].get("Description", None)
            instructions_data = yaml_data[key].get("Instructions", None)
            instruction = self.returnRegister(
                key, Extension_Name, Descr, instructions_data
            )
            a.addInstruction(instruction)
        m.addInstructionBlock(a)
        d.addInstructionMapBlock(m)
        return d

    def returnRegister(self, key, Extension_Name, Descr, instructions_data):
        OperationName = []
        Name = []
        Format = []
        Description = []
        pseudocode = []
        invalid_values = []
        exception_raised = []
        if instructions_data:
            for instruction_name, instruction_data in instructions_data.items():
                for instruction, data in instruction_data.items():
                    OperationName.append(instruction_name)
                    if instruction is not None:
                        Name.append(instruction)
                    else:
                        Name.append("")
                    description = data.get("Description", "")
                    # handle no or an empty description
                    if description is not None:
                        Description.append(description)
                    else:
                        Description.append("")
                    format_str = data.get("Format", "")
                    if format_str is not None:
                        Format.append(format_str)
                    else:
                        Format.append("")
                    pseudocode_str = data.get("Pseudocode", "")
                    if pseudocode_str is not None:
                        pseudocode.append(pseudocode_str)
                    else:
                        pseudocode.append("")
                    exception_raised_str = data.get("Exception_Raised", "")
                    if exception_raised_str is not None:
                        exception_raised.append(exception_raised_str)
                    else:
                        exception_raised.append("")
                    invalid_values_str = data.get("Invalid_Values", "")
                    if invalid_values_str is not None:
                        invalid_values.append(invalid_values_str)
                    else:
                        invalid_values.append("")
        Inst = Instruction(
            key,
            Extension_Name,
            Descr,
            OperationName,
            Name,
            Format,
            Description,
            pseudocode,
            invalid_values,
            exception_raised,
        )
        return Inst


class IsaGenerator:
    """generate isa folder with isa docs"""

    def __init__(self, target):
        self.target = target

    def write(self, file_name, string):
        path = f"./{self.target}/isa/"
        if not os.path.exists(path):
            os.makedirs(path)
        _dest = os.path.join(path, file_name)
        print("writing file " + _dest)
        if not os.path.exists(os.path.dirname(_dest)):
            os.makedirs(os.path.dirname(_dest))

        with open(_dest, "w", encoding="utf-8") as f:
            f.write(string)

    def generateISA(self, generatorClass, document):
        for InstructionMap in document.instructions:
            for InstructionBlock in InstructionMap.InstructionBlockList:
                blockName = InstructionBlock.name

                block = generatorClass(InstructionBlock.name)

                block.setInstructionList(InstructionBlock.Instructionlist)
                s = block.returnAsString()
                file_name = blockName + block.suffix
                self.write(file_name, s)


class CsrGenerator:
    """generate csr folder with csr docs"""

    def __init__(self, target):
        self.target = target

    def write(self, file_name, string):
        path = f"./{self.target}/csr/"
        print(path)
        if not os.path.exists(path):
            os.makedirs(path)
        _dest = os.path.join(path, file_name)
        print("writing file " + _dest)
        if not os.path.exists(os.path.dirname(_dest)):
            os.makedirs(os.path.dirname(_dest))
        with open(_dest, "w", encoding="utf-8") as f:
            f.write(string)

    def generateCSR(self, generatorClass, document):
        for memoryMap in document.memoryMapList:
            for addressBlock in memoryMap.addressBlockList:
                blockName = addressBlock.name
                block = generatorClass(addressBlock.name)

                block.setRegisterList(addressBlock.registerList)
                s = block.returnAsString()
                file_name = blockName + block.suffix
                self.write(file_name, s)
