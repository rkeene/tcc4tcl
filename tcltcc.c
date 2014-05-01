/*
 *  TclTCC - Tcl binding to Tiny C Compiler
 * 
 *  Copyright (c) 2007 Mark Janssen
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

static void TccErrorFunc(Tcl_Interp * interp, char * msg) {
    Tcl_AppendResult(interp, msg, "\n", NULL);
}


static void TccCCommandDeleteProc (ClientData cdata) {
    TCCState * s ;
    s = (TCCState *)cdata;
    Tcl_DecrRefCount(s->tcc_lib_path);
    /* We can delete the compiler if the output was not to memory */
    if (s->output_type != TCC_OUTPUT_MEMORY) {
        tcc_delete(s);
    }
}

static int TccHandleCmd ( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
    unsigned long val;
    int index;
    int res;
    TCCState * s = (TCCState *)cdata ;
    Tcl_Obj * sym_addr;

    static CONST char *options[] = {
        "add_include_path", "add_file",  "add_library", 
        "add_library_path", "add_symbol", "command", "compile",
        "define", "get_symbol", "output_file", "undefine",    (char *) NULL
    };
    enum options {
        TCLTCC_ADD_INCLUDE, TCLTCC_ADD_FILE, TCLTCC_ADD_LIBRARY, 
        TCLTCC_ADD_LIBRARY_PATH, TCLTCC_ADD_SYMBOL, TCLTCC_COMMAND, TCLTCC_COMPILE,
        TCLTCC_DEFINE, TCLTCC_GET_SYMBOL, TCLTCC_OUTPUT_FILE, TCLTCC_UNDEFINE
    };


    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand arg ?arg ...?");
        return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0,
                &index) != TCL_OK) {
        return TCL_ERROR;
    }
    switch (index) {
        case TCLTCC_ADD_INCLUDE:   
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "path");
                return TCL_ERROR;
            } else {
                tcc_add_include_path(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
        case TCLTCC_ADD_FILE:   
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "filename");
                return TCL_ERROR;
            } else {
                if(tcc_add_file(s, Tcl_GetString(objv[2]))!=0) {
                    return TCL_ERROR;
                } else {
                    return TCL_OK;
                }
            }
        case TCLTCC_ADD_LIBRARY:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "lib");
                return TCL_ERROR;
            } else {
                tcc_add_library(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
        case TCLTCC_ADD_LIBRARY_PATH:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "path");
                return TCL_ERROR;
            } else {
                tcc_add_library_path(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
        case TCLTCC_ADD_SYMBOL:
            if (objc != 4) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol value");
                return TCL_ERROR;
            }
            Tcl_GetLongFromObj(interp,objv[3], &val);
            tcc_add_symbol(s,Tcl_GetString(objv[2]),val); 
            return TCL_OK; 
        case TCLTCC_COMMAND:
            if (objc != 4) {
                Tcl_WrongNumArgs(interp, 2, objv, "tclname cname");
                return TCL_ERROR;
            }
            if (!s->relocated) {     
                if(tcc_relocate(s)!=0) {
                    Tcl_AppendResult(interp, "relocating failed", NULL);
                    return TCL_ERROR;
                } else {
                    s->relocated=1;
                }
            }
            if (tcc_get_symbol(s,&val,Tcl_GetString(objv[3]))!=0) {
		    Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[3]),"' not found", NULL);
		    return TCL_ERROR;
	    }

            /*printf("symbol: %x\n",val); */
            Tcl_CreateObjCommand(interp,Tcl_GetString(objv[2]),(void *)val,NULL,NULL);
            return TCL_OK;
        case TCLTCC_COMPILE:
            if(s->relocated == 1) {
                Tcl_AppendResult(interp, "code already relocated, cannot compile more",NULL);
                return TCL_ERROR;
            }
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "ccode");
                return TCL_ERROR;
            } else {

                int i;
                Tcl_GetString(objv[2]);
                i = tcc_compile_string(s,Tcl_GetString(objv[2]));
                if (i!=0) {
                    Tcl_AppendResult(interp,"compilation failed",NULL);
                    return TCL_ERROR;
                } else {
                    return TCL_OK;
                }
            }
        case TCLTCC_DEFINE:
            if (objc != 4) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol value");
                return TCL_ERROR;
            }
            tcc_define_symbol(s,Tcl_GetString(objv[2]),Tcl_GetString(objv[3]));
            return TCL_OK;
        case TCLTCC_GET_SYMBOL:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol");
                return TCL_ERROR;
            }
            if (!s->relocated) {     
                if(tcc_relocate(s)!=0) {
                    Tcl_AppendResult(interp, "relocating failed", NULL);
                    return TCL_ERROR;
                } else {
                    s->relocated=1;
                }
            }
            if(tcc_get_symbol(s,&val,Tcl_GetString(objv[2]))!=0) {
                Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[2]),"' not found", NULL);
                return TCL_ERROR;
            }
            sym_addr = Tcl_NewLongObj(val);
            Tcl_SetObjResult(interp, sym_addr);
            return TCL_OK; 
        case TCLTCC_OUTPUT_FILE:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "filename");
                return TCL_ERROR;
            }
            if (s->relocated) {     
                Tcl_AppendResult(interp, "code already relocated, cannot output to file", NULL);
                return TCL_ERROR;
            }
            if (s->output_type == TCC_OUTPUT_MEMORY) {     
                Tcl_AppendResult(interp, "output_type memory not valid for output to file", NULL);
                return TCL_ERROR;
            }
#ifdef WIN32
            res = tcc_output_pe(s,Tcl_GetString(objv[2]));
#else
            res = tcc_output_file(s,Tcl_GetString(objv[2]));
#endif

            if (res!=0) {
                Tcl_AppendResult(interp, "output to file failed", NULL);
                return TCL_ERROR;
            } else {
                return TCL_OK;
            }
        case TCLTCC_UNDEFINE:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol");
                return TCL_ERROR;
            }
            tcc_undefine_symbol(s,Tcl_GetString(objv[2]));
            return TCL_OK;
        default:
            Tcl_Panic("internal error during option lookup");
    }
    return TCL_OK;
} 

static int TccCreateCmd( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
    TCCState * s;
    static CONST char *types[] = {
        "memory", "exe", "dll", "obj", "preprocess",    (char *) NULL
    };
    int index;
    if (objc < 3 || objc > 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "tcc_libary_path ?output_type? handle");
        return TCL_ERROR;
    }
    if (objc == 3) {
        index = TCC_OUTPUT_MEMORY;
    } else {
        if (Tcl_GetIndexFromObj(interp, objv[2], types, "type", 0,
                    &index) != TCL_OK) {
            return TCL_ERROR;
        }
    }
    s = tcc_new(objv[1]);
    tcc_set_error_func(s, interp, (void *)&TccErrorFunc);
    s->relocated = 0;
    /*printf("type: %d\n", index); */
    tcc_set_output_type(s,index);
    Tcl_CreateObjCommand(interp,Tcl_GetString(objv[objc-1]),TccHandleCmd,s,TccCCommandDeleteProc);

    return TCL_OK;
}

DLL_EXPORT int Tcc_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, "8.4" , 0) == 0L) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp,PACKAGE_NAME,TccCreateCmd,NULL,NULL);
    Tcl_PkgProvide(interp,PACKAGE_NAME,PACKAGE_VERSION);
    return TCL_OK;
}



