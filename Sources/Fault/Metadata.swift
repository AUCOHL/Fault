import Foundation

struct ChainRegister: Codable {
    enum Kind: String, Codable {
        case input
        case output
        case dff
    }
    var name: String
    var kind: Kind
    var width: Int

    init(name: String, kind: Kind, width: Int = 1) {
        self.name = name
        self.kind = kind
        self.width = width
    }
}

struct Metadata: Codable {
    var dffCount: Int
    var order: [ChainRegister]
    var shift: String
    var sin: String
    var sout: String

    init(
        dffCount: Int,
        order: [ChainRegister],
        shift: String,
        sin: String,
        sout: String
    ) {
        self.dffCount = dffCount
        self.order = order
        self.shift = shift
        self.sin = sin
        self.sout = sout
    }
}

var tapCopyRight :String = {
    """
        //////////////////////////////////////////////////////////////////////
        ////                                                              ////
        ////  tap_defines.v                                               ////
        ////                                                              ////
        ////                                                              ////
        ////  This file is part of the JTAG Test Access Port (TAP)        ////
        ////  http://www.opencores.org/projects/jtag/                     ////
        ////                                                              ////
        ////  Author(s):                                                  ////
        ////       Igor Mohor (igorm@opencores.org)                       ////
        ////                                                              ////
        ////                                                              ////
        ////  All additional information is avaliable in the README.txt   ////
        ////  file.                                                       ////
        ////                                                              ////
        //////////////////////////////////////////////////////////////////////
        ////                                                              ////
        //// Copyright (C) 2000 - 2003 Authors                            ////
        ////                                                              ////
        //// This source file may be used and distributed without         ////
        //// restriction provided that this copyright statement is not    ////
        //// removed from the file and that any derivative work contains  ////
        //// the original copyright notice and the associated disclaimer. ////
        ////                                                              ////
        //// This source file is free software; you can redistribute it   ////
        //// and/or modify it under the terms of the GNU Lesser General   ////
        //// Public License as published by the Free Software Foundation; ////
        //// either version 2.1 of the License, or (at your option) any   ////
        //// later version.                                               ////
        ////                                                              ////
        //// This source is distributed in the hope that it will be       ////
        //// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
        //// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
        //// PURPOSE.  See the GNU Lesser General Public License for more ////
        //// details.                                                     ////
        ////                                                              ////
        //// You should have received a copy of the GNU Lesser General    ////
        //// Public License along with this source; if not, download it   ////
        //// from http://www.opencores.org/lgpl.shtml                     ////
        ////                                                              ////
        //////////////////////////////////////////////////////////////////////
    """
}()