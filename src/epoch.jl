# Copyright (c) 2015 Michael Eastwood
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Epochs
    @enum(System, LAST, LMST, GMST1, GAST, UT1, UT2, UTC, TAI, TDT, TCG, TDB, TCB)
    const IAT = TAI
    const GMST = GMST1
    const TT = TDT
    const UT = UT1
    const ET = TT
end

macro epoch_str(sys)
    eval(current_module(),:(Measures.Epochs.$(symbol(sys))))
end

@measure :Epoch 1

@doc """
    type Epoch{sys} <: Measure

This type represents an instance in time (ie. an epoch). The type
parameter `sys` defines the coordinate system.

    Epoch(sys, time::Quantity)

Instantiate an epoch from the given coordinate system and time.
""" Epoch

function get(epoch::Epoch, unit::Unit)
    ccall(("getEpoch",libcasacorewrapper), Cdouble,
          (Ptr{Void},Ptr{Void}), pointer(epoch), pointer(unit))
end

days(epoch::Epoch) = get(epoch,Unit("d"))
seconds(epoch::Epoch) = get(epoch,Unit("s"))

show(io::IO, epoch::Epoch) = print(io,days(epoch)," days")

