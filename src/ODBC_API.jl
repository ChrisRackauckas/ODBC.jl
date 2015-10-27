#ODBC API Function Definitions
#By Jacob Quinn, 2013
#In general, the ODBC functions are implemented to mirror the C header files (sql.h,sqlext.h,sqltypes.h,sqlucode.h)
#A few liberties are taken in utliizing standard Julia functions and idioms
#Format:
 #function name
 #URL reference
 #short function description
 #valid const definitions
 #relevant notes
 #working and tested status
 #function definition code

#Contents
 #Macros and Utility Functions
 #Handle Functions
 #Connection Functions
 #Resultset Metadata Functions
 #Query Functions
 #Resultset Retrieval Functions
 #DBMS Meta Functions
 #Error Handling and Diagnostics

#### Macros and Utility Functions ####

# MULTIROWFETCH sets the default rowset fetch size
# used in retrieving resultset blocks from queries
const MULTIROWFETCH = 65535

# success codes
const SQL_SUCCESS           = Int16(0)
const SQL_SUCCESS_WITH_INFO = Int16(1)

# error codes
const SQL_ERROR             = Int16(-1)
const SQL_INVALID_HANDLE    = Int16(-2)

# status codes
const SQL_STILL_EXECUTING   = Int16(2)
const SQL_NO_DATA           = Int16(100)

const RETURN_VALUES = Dict(SQL_ERROR   => "SQL_ERROR",
                           SQL_NO_DATA => "SQL_NO_DATA",
                           SQL_INVALID_HANDLE  => "SQL_INVALID_HANDLE",
                           SQL_STILL_EXECUTING => "SQL_STILL_EXECUTING")

#Macros to to check if a function returned a success value or not
macro CHECK(func)
    str = string(func)
    quote
        ret = $func
        ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO && throw(ODBCError("$($str) failed; return code: $ret => $(RETURN_VALUES[ret])"))
        nothing
    end
end

macro odbc(func,args,vals...)
    @windows_only quote
        ccall( ($func, ODBC.odbc_dm), stdcall, ODBC.SQLRETURN, $args, $(vals...))
    end
    @unix_only quote
        ccall( ($func, ODBC.odbc_dm), ODBC.SQLRETURN, $args, $(vals...))
    end
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712400(v=vs.85).aspx
function SQLDrivers(env::Ptr{Void},
                    driver_desc::Array{SQLWCHAR,1},
                    desc_length::Array{Int16,1},
                    driver_attr::Array{SQLWCHAR,1},
                    attr_length::Array{Int16,1})
    ret = @odbc(:SQLDriversW,
                (Ptr{Void}, Int16, Ptr{SQLWCHAR}, Int16, Ptr{Int16}, Ptr{SQLWCHAR}, Int16, Ptr{Int16}),
                env, SQL_FETCH_NEXT, driver_desc, length(driver_desc), desc_length, driver_attr, length(driver_attr), attr_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711004(v=vs.85).aspx
function SQLDataSources(env::Ptr{Void},
                        dsn_desc::Vector{SQLWCHAR},
                        desc_length::Array{Int16,1},
                        dsn_attr::Vector{SQLWCHAR},
                        attr_length::Array{Int16,1})
    ret = @odbc(:SQLDataSourcesW,
                (Ptr{Void}, Int16, Ptr{SQLWCHAR}, Int16, Ptr{Int16}, Ptr{SQLWCHAR}, Int16, Ptr{Int16}),
                env, SQL_FETCH_NEXT, dsn_desc, length(dsn_desc), desc_length, dsn_attr, length(dsn_attr), attr_length)
    return ret
end

#### Handle Functions ####

# SQLAllocHandle
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms712455(v=vs.85).aspx
# Description: allocates an environment, connection, statement, or descriptor handle
# Valid handle types
const SQL_HANDLE_ENV  = Int16(1)
const SQL_HANDLE_DBC  = Int16(2)
const SQL_HANDLE_STMT = Int16(3)
const SQL_HANDLE_DESC = Int16(4)
const SQL_NULL_HANDLE = C_NULL

#Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLAllocHandle(handletype::Int16, parenthandle::Ptr{Void}, handle::Ref{Ptr{Void}})
    ret = @odbc(:SQLAllocHandle,
                (Int16, Ptr{Void}, Ptr{Void}),
                handletype, parenthandle, handle)
    return ret
end

# SQLFreeHandle
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms710123(v=vs.85).aspx
# Description: frees resources associated with a specific environment, connection, statement, or descriptor handle
# See SQLAllocHandle for valid handle types
# Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLFreeHandle(handletype::Int16,handle::Ptr{Void})
    ret = @odbc(:SQLFreeHandle,
                (Int16, Ptr{Void}), handletype, handle)
    return ret
end

# SQLSetEnvAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms709285(v=vs.85).aspx
# Description: sets attributes that govern aspects of environments
# Valid attributes; valid values for attribute are indented
const SQL_ATTR_CONNECTION_POOLING = 201
const SQL_CP_OFF = UInt(0)
const SQL_CP_ONE_PER_DRIVER = UInt(1)
const SQL_CP_ONE_PER_HENV = UInt(2)
const SQL_CP_DEFAULT = SQL_CP_OFF
const SQL_ATTR_CP_MATCH = 202
const SQL_CP_RELAXED_MATCH = UInt(1)
const SQL_CP_STRICT_MATCH = UInt(0)
const SQL_ATTR_ODBC_VERSION = 200
const SQL_OV_ODBC2 = 2
const SQL_OV_ODBC3 = 3
const SQL_ATTR_OUTPUT_NTS = 10001
const SQL_TRUE = 1
const SQL_FALSE = 0

#Status: Tested on Windows, Linux, Mac 32/64-bit
function SQLSetEnvAttr{T<:Union{Int,UInt}}(env_handle::Ptr{Void}, attribute::Int, value::T)
    ret = @odbc(:SQLSetEnvAttr,
                (Ptr{Void}, Int, T, Int), env_handle, attribute, value, 0)
    return ret
end

# SQLGetEnvAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms709276(v=vs.85).aspx
# Description: returns the current setting of an environment attribute
# Valid attributes: See SQLSetEnvAttr
# Status:
function SQLGetEnvAttr(env::Ptr{Void},attribute::Int,value::Array{Int,1},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetEnvAttr,
                (Ptr{Void}, Int, Ptr{Int}, Int, Ptr{Int}),
                env, attribute, value, 0, bytes_returned)
    return ret
end

# SQLSetConnectAttr
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms713605(v=vs.85).aspx
# Description: sets attributes that govern aspects of connections.
# Valid attributes
const SQL_ATTR_ACCESS_MODE = 101
const SQL_MODE_READ_ONLY = UInt(1)
const SQL_MODE_READ_WRITE = UInt(0)
#const SQL_ATTR_ASYNC_DBC_EVENT
#pointer
#const SQL_ATTR_ASYNC_DBC_FUNCTIONS_ENABLE
#const SQL_ASYNC_DBC_ENABLE_ON = UInt()
#const SQL_ASYNC_DBC_ENABLE_OFF = UInt()
#const SQL_ATTR_ASYNC_DBC_PCALLBACK
#pointer
#const SQL_ATTR_ASYNC_DBC_PCONTEXT
#pointer
const SQL_ATTR_ASYNC_ENABLE = 4
const SQL_ASYNC_ENABLE_OFF = UInt(0)
const SQL_ASYNC_ENABLE_ON = UInt(1)
const SQL_ATTR_AUTOCOMMIT = 102
const SQL_AUTOCOMMIT_OFF = UInt(0)
const SQL_AUTOCOMMIT_ON = UInt(1)
const SQL_ATTR_CONNECTION_TIMEOUT = 113
#uint of how long you want the connection timeout
const SQL_ATTR_CURRENT_CATALOG = 109
#string/Ptr{UInt8} of default database to use
#const SQL_ATTR_DBC_INFO_TOKEN
#pointer
const SQL_ATTR_ENLIST_IN_DTC = 1207
#pointer: Pass a DTC OLE transaction object that specifies the transaction to export to
# SQL Server, or SQL_DTC_DONE to end the connection's DTC association.
const SQL_ATTR_LOGIN_TIMEOUT = 103
#uint of how long you want the login timeout
const SQL_ATTR_METADATA_ID = 10014
#SQL_TRUE, SQL_FALSE
const SQL_ATTR_ODBC_CURSORS = 110
const SQL_CUR_USE_IF_NEEDED = UInt(0)
const SQL_CUR_USE_ODBC = UInt(1)
const SQL_CUR_USE_DRIVER = UInt(2)
const SQL_ATTR_PACKET_SIZE = 112
#uint for network packet size
const SQL_ATTR_QUIET_MODE = 111
#window handle pointer
const SQL_ATTR_TRACE = 104
const SQL_OPT_TRACE_OFF = UInt(0)
const SQL_OPT_TRACE_ON = UInt(1)
const SQL_ATTR_TRACEFILE = 105
#A null-terminated character string containing the name of the trace file.
const SQL_ATTR_TRANSLATE_LIB = 106
# A null-terminated character string containing the name of a library containing the functions SQLDriverToDataSource and
# SQLDataSourceToDriver that the driver accesses to perform tasks such as character set translation.
const SQL_ATTR_TRANSLATE_OPTION = 107
#A 32-bit flag value that is passed to the translation DLL.
const SQL_ATTR_TXN_ISOLATION = 108
#A 32-bit bitmask that sets the transaction isolation level for the current connection.

#Valid value_length
const SQL_IS_POINTER = -4
const SQL_IS_INTEGER = -6
const SQL_IS_UINTEGER = -5
const SQL_NTS = -3

#length of string or binary stream
#Status:
function SQLSetConnectAttr(dbc::Ptr{Void},attribute::Int,value::UInt,value_length::Int)
    ret = @odbc(:SQLSetConnectAttrW,
                (Ptr{Void},Int,UInt,Int),
                dbc,attribute,value,value_length)
    return ret
end

function SQLSetConnectAttr(dbc::Ptr{Void},attribute::Int,value::Array{Int},value_length::Int)
    ret = @odbc(:SQLSetConnectAttrW,
                (Ptr{Void},Int,Ptr{Int},Int),
                dbc,attribute,value,value_length)
    return ret
end

#SQLGetConnectAttr
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710297(v=vs.85).aspx
#Description: returns the current setting of a connection attribute.
#Valid attributes: see SQLSetConnectAttr in addition to those below
const SQL_ATTR_AUTO_IPD = 10001
#SQL_TRUE, SQL_FALSE
const SQL_ATTR_CONNECTION_DEAD = 1209
const SQL_CD_TRUE = 1
const SQL_CD_FALSE = 0
#Status:
function SQLGetConnectAttr{T,N}(dbc::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetConnectAttrW,
                (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
                dbc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLSetStmtAttr
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712631(v=vs.85).aspx
#Description: sets attributes related to a statement.
#Valid attributes
const SQL_ATTR_ROW_STATUS_PTR = 25
const SQL_ATTR_ROWS_FETCHED_PTR  = 26
const SQL_ATTR_ROW_ARRAY_SIZE = 27
#this sets the rowset size for ExtendedFetch and FetchScroll
#Valid value_length: See SQLSetConnectAttr; SQL_IS_POINTER, SQL_IS_INTEGER, SQL_IS_UINTEGER, SQL_NTS
#Status:
function SQLSetStmtAttr(stmt::Ptr{Void},attribute::Int,value::UInt,value_length::Int)
    ret = @odbc(:SQLSetStmtAttrW,
                (Ptr{Void},Int,UInt,Int),
                stmt,attribute,value,value_length)
    return ret
end

function SQLSetStmtAttr(stmt::Ptr{Void},attribute::Int,value::Array{Int},value_length::Int)
    ret = @odbc(:SQLSetStmtAttrW,
                (Ptr{Void},Int,Ptr{Int},Int),
                stmt,attribute,value,value_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715438(v=vs.85).aspx
function SQLGetStmtAttr{T,N}(stmt::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetStmtAttrW,
                (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
                stmt,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLFreeStmt
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709284(v=vs.85).aspx
#Description: stops processing associated with a specific statement,
# closes any open cursors associated with the statement,
# discards pending results, or, optionally,
# frees all resources associated with the statement handle.
#Valid param
const SQL_CLOSE = UInt16(0)
const SQL_RESET_PARAMS = UInt16(3)
const SQL_UNBIND = UInt16(2)

#Status:
function SQLFreeStmt(stmt::Ptr{Void},param::UInt16)
    ret = @odbc(:SQLFreeStmt,
                (Ptr{Void},UInt16),
                stmt, param)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713560(v=vs.85).aspx
function SQLSetDescField{T,N}(desc::Ptr{Void},i::Int16,field_id::Int16,value::Array{T,N},value_length::Array{Int,1})
    ret = @odbc(:SQLSetDescFieldW,
                (Ptr{Void},Int16,Int16,Ptr{T},Int),
                desc,field_id,value,value_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716370(v=vs.85).aspx
function SQLGetDescField{T,N}(desc::Ptr{Void},i::Int16,attribute::Int16,value::Array{T,N},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetDescFieldW,
                (Ptr{Void},Int16,Int16,Ptr{T},Int,Ptr{Int}),
                desc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710921(v=vs.85).aspx
function SQLGetDescRec(desc::Ptr{Void},i::Int16,name::Array{UInt8,1},name_length::Array{Int16,1},type_ptr::Array{Int16,1},subtype_ptr::Array{Int16,1},length_ptr::Array{Int,1},precision_ptr::Array{Int16,1},scale_ptr::Array{Int16,1},nullable_ptr::Array{Int16,1},)
    ret = @odbc(:SQLGetDescRecW,
                (Ptr{Void},Int16,Ptr{UInt8},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16},Ptr{Int16}),
                desc,i,name,length(name),name_length,type_ptr,subtype_ptr,length_ptr,precision_ptr,scale_ptr,nullable_ptr)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715378(v=vs.85).aspx
function SQLCopyDesc(source_desc::Ptr{Void},dest_desc::Ptr{Void})
    ret = @odbc(:SQLCopyDesc,
                (Ptr{Void},Ptr{Void}),
                source_desc,dest_desc)
    return ret
end

### Connection Functions ###
# SQLConnect
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms711810(v=vs.85).aspx
# Description: establishes connections to a driver and a data source
# Status:
function SQLConnect(dbc::Ptr{Void},dsn::AbstractString,username::AbstractString,password::AbstractString)
    ret = @odbc(:SQLConnectW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                dbc,utf(dsn),length(dsn),utf(username),length(username),utf(password),length(password))
    return ret
end

#SQLDriverConnect
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715433(v=vs.85).aspx
#Description:
#Valid driver_prompt
const SQL_DRIVER_COMPLETE = UInt16(1)
const SQL_DRIVER_COMPLETE_REQUIRED = UInt16(3)
const SQL_DRIVER_NOPROMPT = UInt16(0)
const SQL_DRIVER_PROMPT = UInt16(2)
#Status:
function SQLDriverConnect(dbc::Ptr{Void},window_handle::Ptr{Void},conn_string::AbstractString,out_conn::Vector{SQLWCHAR},out_buff::Vector{Int16},driver_prompt::UInt16)
    ret = @odbc(:SQLDriverConnectW,
                (Ptr{Void},Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{Int16},UInt16),
                dbc,window_handle,utf(conn_string),length(conn_string),out_conn,length(out_conn),out_buff,driver_prompt)
    return ret
end
#SQLBrowseConnect
 #http://msdn.microsoft.com/en-us/library/windows/desktop/ms714565(v=vs.85).aspx
 #Description: supports an iterative method of discovering and enumerating the attributes and attribute values required to connect to a data source
 #Status:
function SQLBrowseConnect(dbc::Ptr{Void},instring::AbstractString,outstring::Array{SQLWCHAR,1},indicator::Array{Int16,1})
    ret = @odbc(:SQLBrowseConnectW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{Int16}),
                dbc,utf(instring),length(instring),utf(outstring),length(outstring),indicator)
    return ret
end
#SQLDisconnect
 #http://msdn.microsoft.com/en-us/library/windows/desktop/ms713946(v=vs.85).aspx
 #Description: closes the connection associated with a specific connection handle
 #Status:
function SQLDisconnect(dbc::Ptr{Void})
    ret = @odbc(:SQLDisconnect,
                (Ptr{Void},),
                dbc)
    return ret
end
#SQLGetFunctions
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709291(v=vs.85).aspx
#Descriptions:
#Valid functionid

#supported will be SQL_TRUE or SQL_FALSE
#Status:
function SQLGetFunctions(dbc::Ptr{Void},functionid::UInt16,supported::Array{UInt16,1})
    ret = @odbc(:SQLGetFunctions,
                (Ptr{Void},UInt16,Ptr{UInt16}),
                dbc,functionid,supported)
    return ret
end

#SQLGetInfo
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711681(v=vs.85).aspx
#Description:
#Status:
function SQLGetInfo{T,N}(dbc::Ptr{Void},attribute::Int,value::Array{T,N},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetInfoW,
                (Ptr{Void},Int,Ptr{T},Int,Ptr{Int}),
                dbc,attribute,value,sizeof(T)*N,bytes_returned)
    return ret
end

#### Query Functions ####
#SQLNativeSql
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714575(v=vs.85).aspx
#Description: returns the SQL string as modified by the driver
#Status:
function SQLNativeSql(dbc::Ptr{Void},query_string::AbstractString,output_string::Array{SQLWCHAR,1},length_ind::Array{Int,1})
    ret = @odbc(:SQLNativeSql,
                (Ptr{Void},Ptr{SQLWCHAR},Int,Ptr{SQLWCHAR},Int,Ptr{Int}),
                dbc,utf(query_string),length(query_string),output_string,length(output_string),length_ind)
    return ret
end

#SQLGetTypeInfo
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714632(v=vs.85).aspx
#Description:
#valid sqltype
#const SQL_ALL_TYPES =
#Status:
function SQLGetTypeInfo(stmt::Ptr{Void},sqltype::Int16)
    ret = @odbc(:SQLGetTypeInfo,
                (Ptr{Void},Int16),
                stmt,sqltype)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713824(v=vs.85).aspx
function SQLPutData{T}(stmt::Ptr{Void},data::Array{T},data_length::Int)
    ret = @odbc(:SQLPutData,
                (Ptr{Void},Ptr{T},Int),
                stmt,data,data_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710926(v=vs.85).aspx
function SQLPrepare(stmt::Ptr{Void},query_string::AbstractString)
    ret = @odbc(:SQLPrepareW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16),
                stmt,utf(query_string),length(query_string))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713584(v=vs.85).aspx
function SQLExecute(stmt::Ptr{Void})
    ret = @odbc(:SQLExecute,
                (Ptr{Void},),
                stmt)
    return ret
end

#SQLExecDirect
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713611(v=vs.85).aspx
#Description: executes a preparable statement
#Status:
function SQLExecDirect(stmt::Ptr{Void},query::AbstractString)
    ret = @odbc(:SQLExecDirectW,
                (Ptr{Void},Ptr{SQLWCHAR},Int),
                stmt,utf(query),length(query))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714112(v=vs.85).aspx
function SQLCancel(stmt::Ptr{Void})
    ret = @odbc(:SQLCancel,
                (Ptr{Void},),
                stmt)
    return ret
end

#### Resultset Metadata Functions ####
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715393(v=vs.85).aspx
function SQLNumResultCols(stmt::Ptr{Void},cols::Array{Int16,1})
    ret = @odbc(:SQLNumResultCols,
                (Ptr{Void},Ptr{Int16}),
                stmt, cols)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711835(v=vs.85).aspx
function SQLRowCount(stmt::Ptr{Void},rows::Array{Int,1})
    ret = @odbc(:SQLRowCount,
                (Ptr{Void},Ptr{Int}),
                stmt, rows)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713558(v=vs.85).aspx
# function SQLColAttribute(stmt::Ptr{Void},x::Int,)
#     ret = @odbc(:SQLColAttributeW,
#                 (Ptr{Void},UInt16,UInt16,Ptr,Int16,Ptr{Int16},Ptr{Int}),
#                 stmt,x,)
#     return ret
# end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716289(v=vs.85).aspx
function SQLDescribeCol(stmt::Ptr{Void},x::Int,column_name::Array{SQLWCHAR,1},name_length::Array{Int16,1},datatype::Array{Int16,1},column_size::Array{Int,1},decimal_digits::Array{Int16,1},nullable::Array{Int16,1})
    ret = @odbc(:SQLDescribeColW,
                (Ptr{Void},UInt16,Ptr{SQLWCHAR},Int16,Ptr{Int16},Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
                stmt,x,utf(column_name),length(column_name),name_length,datatype,column_size,decimal_digits,nullable)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710188(v=vs.85).aspx
function SQLDescribeParam(stmt::Ptr{Void},x::Int,sqltype::Array{Int16,1},column_size::Array{Int,1},decimal_digits::Array{Int16,1},nullable::Array{Int16,1})
    ret = @odbc(:SQLDescribeParam,
                (Ptr{Void},UInt16,Ptr{Int16},Ptr{Int},Ptr{Int16},Ptr{Int16}),
                stmt,x,sqltype,column_size,decimal_digits,nullable)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712366(v=vs.85).aspx
function SQLParamData(stmt::Ptr{Void},ptr_buffer::Array{Ptr{Void},1})
    ret = @odbc(:SQLParamData,
                (Ptr{Void},Ptr{Void}),
                stmt,ptr_buffer)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715409(v=vs.85).aspx
function SQLNumParams(stmt::Ptr{Void},param_count::Array{Int16,1})
    ret = @odbc(:SQLNumParams,
                (Ptr{Void},Ptr{Int16}),
                stmt,param_count)
    return ret
end

#### Resultset Retrieval Functions ####
#SQLBindParameter
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710963(v=vs.85).aspx
#Description:
#valid iotype
const SQL_PARAM_INPUT = Int16(1)
const SQL_PARAM_OUTPUT = Int16(4)
const SQL_PARAM_INPUT_OUTPUT = Int16(2)
#const SQL_PARAM_INPUT_OUTPUT_STREAM = Int16()
#const SQL_PARAM_OUTPUT_STREAM = Int16()
#Status:
function SQLBindParameter{T}(stmt::Ptr{Void},x::Int,iotype::Int16,ctype::Int16,sqltype::Int16,column_size::Int,decimal_digits::Int,param_value::Array{T},param_size::Int)
    ret = @odbc(:SQLBindParameter,
                (Ptr{Void},UInt16,Int16,Int16,Int16,UInt,Int16,Ptr{T},Int,Ptr{Void}),
                stmt,x,iotype,ctype,sqltype,column_size,decimal_digits,param_value,param_size,C_NULL)
    return ret
end
SQLSetParam = SQLBindParameter

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711010(v=vs.85).aspx
function SQLBindCols{T,N}(stmt::Ptr{Void},x::Int,ctype::Int16,holder::Array{T,N},jlsize::Int,indicator::Array{Int,1})
    ret = @odbc(:SQLBindCol,
                (Ptr{Void},UInt16,Int16,Ptr{T},Int,Ptr{Int}),
                stmt,x,ctype,holder,jlsize,indicator)
    return ret
end

function SQLBindCols(stmt::Ptr{Void},x::Int,ctype::Int16,holder::Array{UTF8String,1},jlsize::Int,indicator::Array{Int,1})
    ret = @odbc(:SQLBindCol,
                (Ptr{Void},UInt16,Int16,Ptr{UInt8},Int,Ptr{Int}),
                stmt,x,ctype,holder,jlsize,indicator)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711707(v=vs.85).aspx
function SQLSetCursorName(stmt::Ptr{Void},cursor::AbstractString)
    ret = @odbc(:SQLSetCursorNameW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16),
                stmt,utf(cursor),length(cursor))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716209(v=vs.85).aspx
function SQLGetCursorName(stmt::Ptr{Void},cursor::Array{UInt8,1},cursor_length::Array{Int16,1})
    ret = @odbc(:SQLGetCursorNameW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{Int16}),
                stmt,utf(cursor),length(cursor),cursor_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715441(v=vs.85).aspx
function SQLGetData{T,N}(stmt::Ptr{Void},i::Int,ctype::Int16,value::Array{T,N},bytes_returned::Array{Int,1})
    ret = @odbc(:SQLGetData,
                (Ptr{Void},UInt16,Int16,Ptr{T},Int,Ptr{Int}),
                stmt,i,ctype,value,sizeof(T)*N,bytes_returned)
    return ret
end

#SQLFetchScroll
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714682(v=vs.85).aspx
#Description:
#valid fetch_orientation
const SQL_FETCH_NEXT = Int16(1)
const SQL_FETCH_PRIOR = Int16(4)
const SQL_FETCH_FIRST = Int16(2)
const SQL_FETCH_LAST = Int16(3)
const SQL_FETCH_ABSOLUTE = Int16(5)
const SQL_FETCH_RELATIVE = Int16(6)
const SQL_FETCH_BOOKMARK = Int16(8)
#Status:
function SQLFetchScroll(stmt::Ptr{Void},fetch_orientation::Int16,fetch_offset::Int)
    ret = @odbc(:SQLFetchScroll,
                (Ptr{Void},Int16,Int),
                stmt,fetch_orientation,fetch_offset)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713591(v=vs.85).aspx
function SQLExtendedFetch(stmt::Ptr{Void},fetch_orientation::UInt16,fetch_offset::Int,row_count_ptr::Array{Int,1},row_status_array::Array{Int16,1})
    ret = @odbc(:SQLExtendedFetch,
                (Ptr{Void},UInt16,Int,Ptr{Int},Ptr{Int16}),
                stmt,fetch_orientation,fetch_offset,row_count_ptr,row_status_array)
    return ret
end

#SQLSetPos
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713507(v=vs.85).aspx
#Description:
#valid operation
const SQL_POSITION = UInt16(0) #SQLSetPos
const SQL_REFRESH = UInt16(1) #SQLSetPos
const SQL_UPDATE = UInt16(2) #SQLSetPos
const SQL_DELETE = UInt16(3) #SQLSetPos
#valid lock_type
const SQL_LOCK_NO_CHANGE = UInt16(0) #SQLSetPos
const SQL_LOCK_EXCLUSIVE = UInt16(1) #SQLSetPos
const SQL_LOCK_UNLOCK = UInt16(2) #SQLSetPos
#Status
function SQLSetPos{T}(stmt::Ptr{Void},rownumber::T,operation::UInt16,lock_type::UInt16)
    ret = @odbc(:SQLSetPos,
                (Ptr{Void},T,UInt16,UInt16),
                stmt,rownumber,operation,lock_type)
    return ret
end #T can be Uint64 or UInt16 it seems

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714673(v=vs.85).aspx
function SQLMoreResults(stmt::Ptr{Void})
    ret = @odbc(:SQLMoreResults,
                (Ptr{Void},),
                stmt)
    return ret
end

#SQLEndTran
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716544(v=vs.85).aspx
#Description:
#valid completion_type
const SQL_COMMIT = Int16(0) #SQLEndTran
const SQL_ROLLBACK = Int16(1) #SQLEndTran
#Status:
function SQLEndTran(handletype::Int16,handle::Ptr{Void},completion_type::Int16)
    ret = @odbc(:SQLEndTran,
                (Int16,Ptr{Void},Int16),
                handletype,handle,completion_type)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709301(v=vs.85).aspx
function SQLCloseCursor(stmt::Ptr{Void})
    ret = @odbc(:SQLCloseCursor,
                (Ptr{Void},),
                stmt)
    return ret
end

#SQLBulkOperations
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms712471(v=vs.85).aspx
#Description:
#valid operation
const SQL_ADD = UInt16(4) #SQLBulkOperations
const SQL_UPDATE_BY_BOOKMARK = UInt16(5) #SQLBulkOperations
const SQL_DELETE_BY_BOOKMARK = UInt16(6) #SQLBulkOperations
const SQL_FETCH_BY_BOOKMARK = UInt16(7) #SQLBulkOperations
#Status:
function SQLBulkOperations(stmt::Ptr{Void},operation::UInt16)
    ret = @odbc(:SQLBulkOperations,
                (Ptr{Void},UInt16),
                stmt,operation)
    return ret
end

#### DBMS Meta Functions ####
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711683(v=vs.85).aspx
function SQLColumns(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString,column::AbstractString)
    ret = @odbc(:SQLColumnsW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table),utf(column),length(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716336(v=vs.85).aspx
function SQLColumnPrivileges(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString,column::AbstractString)
    ret = @odbc(:SQLColumnPrivilegesW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table),utf(column),length(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms709315(v=vs.85).aspx
function SQLForeignKeys(stmt::Ptr{Void},pkcatalog::AbstractString,pkschema::AbstractString,pktable::AbstractString,fkcatalog::AbstractString,fkschema::AbstractString,fktable::AbstractString)
    ret = @odbc(:SQLForeignKeysW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(pkcatalog),utf(schema),length(pkschema),utf(table),length(pktable),utf(catalog),length(fkcatalog),utf(schema),length(fkschema),utf(table),length(fktable))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711005(v=vs.85).aspx
function SQLPrimaryKeys(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString)
    ret = @odbc(:SQLPrimaryKeysW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711701(v=vs.85).aspx
function SQLProcedureColumns(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,proc::AbstractString,column::AbstractString)
    ret = @odbc(:SQLProcedureColumnsW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),proc,length(proc),utf(column),length(column))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms715368(v=vs.85).aspx
function SQLProcedures(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,proc::AbstractString)
    ret = @odbc(:SQLProceduresW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),proc,length(proc))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711831(v=vs.85).aspx
function SQLTables(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString,table_type::AbstractString)
    ret = @odbc(:SQLTablesW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table),table_type,length(table_type))
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms713565(v=vs.85).aspx
function SQLTablePrivileges(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString)
    ret = @odbc(:SQLTablePrivilegesW,
                (Ptr{Void},Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table))
    return ret
end

#SQLStatistics
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms711022(v=vs.85).aspx
#Description:
#valid unique
const SQL_INDEX_ALL = UInt16(1)
const SQL_INDEX_CLUSTERED = UInt16(1)
const SQL_INDEX_HASHED = UInt16(2)
const SQL_INDEX_OTHER = UInt16(3)
const SQL_INDEX_UNIQUE = UInt16(0)
#valid reserved
const SQL_ENSURE = UInt16(1)
const SQL_QUICK = UInt16(0)
#Status:
function SQLStatistics(stmt::Ptr{Void},catalog::AbstractString,schema::AbstractString,table::AbstractString,unique::UInt16,reserved::UInt16)
    ret = @odbc(:SQLStatisticsW,
                (Ptr{Void},Ptr{UInt8},Int16,Ptr{UInt8},Int16,Ptr{UInt8},Int16,UInt16,UInt16),
                stmt,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table),unique,reserved)
    return ret
end

#SQLSpecialColumns
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms714602(v=vs.85).aspx
#Description:
#valid id_type
const SQL_BEST_ROWID        = Int16(1) #SQLSpecialColumns
const SQL_ROWVER            = Int16(2) #SQLSpecialColumns
#valid scope
const SQL_SCOPE_CURROW      = Int16(0) #SQLSpecialColumns
const SQL_SCOPE_SESSION     = Int16(2) #SQLSpecialColumns
const SQL_SCOPE_TRANSACTION = Int16(1) #SQLSpecialColumns
#valid nullable
const SQL_NO_NULLS          = Int16(0) #SQLSpecialColumns
const SQL_NULLABLE          = Int16(1) #SQLSpecialColumns
#const SQL_NULLABLE_UNKNOWN = Int16() #SQLSpecialColumns
#Status:
function SQLSpecialColumns(stmt::Ptr{Void},id_type::Int16,catalog::AbstractString,schema::AbstractString,table::AbstractString,scope::Int16,nullable::Int16)
    ret = @odbc(:SQLSpecialColumnsW,
                (Ptr{Void},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Ptr{SQLWCHAR},Int16,Int16,Int16),
                stmt,id_type,utf(catalog),length(catalog),utf(schema),length(schema),utf(table),length(table),scope,nullable)
    return ret
end

#### Error Handling Functions ####
#TODO: add consts
#http://msdn.microsoft.com/en-us/library/windows/desktop/ms710181(v=vs.85).aspx
function SQLGetDiagField(handletype::Int16,handle::Ptr{Void},i::Int16,diag_id::Int16,diag_info::Array{SQLWCHAR,1},buffer_length::Int16,diag_length::Array{Int16,1})
    ret = @odbc(:SQLGetDiagFieldW,
                (Int16,Ptr{Void},Int16,Int16,Ptr{SQLWCHAR},Int16,Ptr{Int16}),
                handletype,handle,i,diag_id,utf(diag_info),buffer_length,msg_length)
    return ret
end

#http://msdn.microsoft.com/en-us/library/windows/desktop/ms716256(v=vs.85).aspx
function SQLGetDiagRec(handletype::Int16,handle::Ptr{Void},i::Int16,state::Array{SQLWCHAR,1},native::Array{Int,1},error_msg::Array{SQLWCHAR,1},msg_length::Array{Int16,1})
    ret = @odbc(:SQLGetDiagRecW,
                (Int16,Ptr{Void},Int16,Ptr{SQLWCHAR},Ptr{Int},Ptr{SQLWCHAR},Int16,Ptr{Int16}),
                handletype,handle,i,utf(state),native,utf(error_msg),length(error_msg),msg_length)
    return ret
end
