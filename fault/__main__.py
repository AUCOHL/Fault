import os
import sys
import shutil
import find_libpython

__dir__ = os.path.dirname(os.path.realpath(__file__))

def prepare_env():
    env = os.environ.copy()
    env["PATH"] = f"{__dir__}:{os.environ['PATH']}"
    env["PYTHON_LIBRARY"] = find_libpython.find_libpython()

    iverilog = env.get("FAULT_IVERILOG", shutil.which("iverilog"))
    if iverilog is not None:
        env["FAULT_IVERILOG"] = iverilog
        env["PYVERILOG_IVERILOG"] = iverilog
        
        ivl_path_rel = os.path.join(os.path.dirname(os.path.dirname(iverilog)), "lib", "ivl")
        if not os.path.isdir(ivl_path_rel):
            ivl_path_rel = None
        ivl_path = env.get("FAULT_IVL_BASE", ivl_path_rel)
        env["FAULT_IVL_BASE"] = ivl_path
        
    yosys = env.get("FAULT_YOSYS", shutil.which("yosys") or shutil.which("yowasp-yosys"))
    if yosys is not None:
        env["FAULT_YOSYS"] = yosys
    
    return env

def exec_fault():
    fault_exe = os.path.join(__dir__, "fault.exe")
    os.execle(fault_exe, "fault", *sys.argv[1:], prepare_env())


if __name__ == '__main__':
    exec_fault()
