# Copyright (c) 2015-2017 Michael Eastwood
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

@noinline function column_length_mismatch_error(column_length, table_rows)
    err("column length ($column_length) must match the number of rows ($table_rows)")
end

@noinline function column_missing_error(column)
    err("column \"$column\" is missing from the table")
end

@noinline function column_element_type_error(column)
    err("element type mismatch for column \"$column\"")
end

@noinline function column_shape_error(column)
    err("array shape mismatch for column \"$column\"")
end

"""
    Tables.num_columns(table)

Returns the number of columns in the given table.

**Arguments:**

**Usage:**

**See also:**
"""
function num_columns(table::Table)
    ccall((:num_columns, libcasacorewrapper), Cuint,
          (Ptr{CasaCoreTable},), table) |> Int
end

function column_exists(table::Table, column::String)
    ccall((:column_exists, libcasacorewrapper), Bool,
          (Ptr{CasaCoreTable}, Ptr{Cchar}),
          table, column)
end

for T in typelist
    typestr = type2str[T]
    c_add_scalar_column = String(Symbol(:add_scalar_column_, typestr))
    c_add_array_column  = String(Symbol(:add_array_column_, typestr))

    @eval function add_column!(table::Table, column::String, ::Type{$T}, shape::Tuple{Int})
        Nrows = num_rows(table)
        if shape[1] != Nrows
            column_length_mismatch_error(shape[1], Nrows)
        end
        ccall(($c_add_scalar_column, libcasacorewrapper), Void,
              (Ptr{CasaCoreTable}, Ptr{Cchar}), table, column)
        column
    end

    @eval function add_column!(table::Table, column::String, ::Type{$T}, shape::Tuple)
        Nrows = num_rows(table)
        if shape[end] != Nrows
            column_length_mismatch_error(shape[end], Nrows)
        end
        cell_shape = convert(Vector{Cint}, collect(shape[1:end-1]))
        ccall(($c_add_array_column, libcasacorewrapper), Void,
              (Ptr{CasaCoreTable}, Ptr{Cchar}, Ptr{Cint}, Cint),
              table, column, cell_shape, length(cell_shape))
        column
    end
end

"""
    Tables.add_column!(table, column, element_type, shape)
"""
add_column!

"""
    Tables.remove_column!(table, column)

Remove the specified column from the table.
"""
function remove_column!(table::Table, column::String)
    ccall(("remove_column", libcasacorewrapper), Void,
          (Ptr{CasaCoreTable}, Ptr{Cchar}), table, column)
end

"Get the column element type and shape."
function column_info(table::Table, column::String)
    element_type = Ref{Cint}(0)
    dimension    = Ref{Cint}(0)
    shape_ptr = ccall((:column_info, libcasacorewrapper), Ptr{Cint},
                      (Ptr{CasaCoreTable}, Ptr{Cchar}, Ref{Cint}, Ref{Cint}),
                      table, column, element_type, dimension)
    T = enum2type[TypeEnum(element_type[])]
    shape = unsafe_wrap(Vector{Cint}, shape_ptr, dimension[], true)
    T, tuple(shape...)
end

function Base.getindex(table::Table, column::String)
    if !column_exists(table, column)
        column_missing_error(column)
    end
    T, shape = column_info(table, column)
    read_column(table, column, T, shape)
end

function Base.setindex!(table::Table, value, column::String)
    if !column_exists(table, column)
        add_column!(table, column, eltype(value), size(value))
    end
    T, shape = column_info(table, column)
    if T != eltype(value)
        column_element_type_error(column)
    end
    if shape != size(value)
        column_shape_error(column)
    end
    write_column!(table, value, column)
end

for T in typelist_nostring
    typestr = type2str[T]
    c_get_column = String(Symbol(:get_column_, typestr))
    c_put_column = String(Symbol(:put_column_, typestr))

    @eval function read_column(table::Table, column::String, ::Type{$T}, shape)
        N = length(shape)
        ptr = ccall(($c_get_column, libcasacorewrapper), Ptr{$T},
                    (Ptr{CasaCoreTable}, Ptr{Cchar}), table, column)
        unsafe_wrap(Array{$T, N}, ptr, shape, true)
    end

    @eval function write_column!(table::Table, value::Array{$T}, column::String)
        shape = convert(Vector{Cint}, collect(size(value)))
        ccall(($c_put_column, libcasacorewrapper), Void,
              (Ptr{CasaCoreTable}, Ptr{Cchar}, Ptr{$T}, Ptr{Cint}, Cint),
              table, column, value, shape, length(shape))
        value
    end
end

#function read_column(table::Table, column::String, ::Type{String}, shape)
#    N = length(shape)
#    ptr = ccall(("getColumn_string", libcasacorewrapper), Ptr{Ptr{Cchar}},
#                (Ptr{CasaCoreTable}, Ptr{Cchar}), table, column)
#    arr = unsafe_wrap(Array{Ptr{Cchar}, N}, ptr, shape, true)
#    [String(unsafe_wrap(Vector{UInt8}, my_ptr, true)) for my_ptr in arr]
#end
#
#function write_column!(table::Table, value::Array{String}, column::String)
#    shape = convert(Vector{Cint}, collect(size(value)))
#    ccall(("putColumn_string", libcasacorewrapper), Void,
#          (Ptr{CasaCoreTable}, Ptr{Cchar}, Ptr{Ptr{Cchar}}, Ptr{Cint}, Cint),
#          table, column, value, shape, length(shape))
#    value
#end

