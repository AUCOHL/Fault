import os
import sys
import shutil
import find_libpython

__dir__ = os.path.dirname(os.path.realpath(__file__))

fault_exe = os.path.join(__dir__, "fault.exe")

env = os.environ.copy()
env["PATH"] = f"{__dir__}:{os.environ['PATH']}"
env["PYTHON_LIBRARY"] = find_libpython.find_libpython()

iverilog = env.get("FAULT_IVERILOG", shutil.which("iverilog"))
if iverilog is not None:
    env["FAULT_IVERILOG"] = iverilog
    env["PYVERILOG_IVERILOG"] = iverilog
    
    ivl_path_rel = os.path.join(os.path.dirname(os.path.dirname(iverilog)), "lib", "ivl")
    ivl_path = env.get("FAULT_IVL_BASE", ivl_path_rel)
    env["FAULT_IVL_BASE"] = ivl_path

os.execle(fault_exe, "fault", *sys.argv[1:], env)
