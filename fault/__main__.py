import os
import sys
import shutil
import find_libpython
from pathlib import Path

__dir__ = Path(__file__).resolve().parent


def prepare_env():
    env = os.environ.copy()
    env["PATH"] = f"{__dir__}:{os.environ['PATH']}"
    env["PYTHON_LIBRARY"] = find_libpython.find_libpython()

    iverilog = env.get("FAULT_IVERILOG", shutil.which("iverilog"))
    if iverilog is not None:
        iverilog = Path(iverilog).resolve()
        env["FAULT_IVERILOG"] = str(iverilog)
        env["PYVERILOG_IVERILOG"] = str(iverilog)

        # Some custom installations of IcarusVerilog have trouble finding the
        # IVL directory on their own. We should try to help  a little bit.
        relative_ivl_path = iverilog.parent.parent / "lib" / "ivl"
        if not relative_ivl_path.is_dir():
            relative_ivl_path = None
        if final_ivl_path := env.get("FAULT_IVL_BASE", relative_ivl_path):
            env["FAULT_IVL_BASE"] = str(final_ivl_path)
        else:
            # If ultimately unset, that's fine. We'll just hope IcarusVerilog
            # can manage.
            pass
    else:
        print(
            f"WARNING: IcarusVerilog was not found in either FAULT_IVERILOG or PATH. Fault ATPG, Scan Chain Verification and TAP verification will all not work.",
            file=sys.stderr,
        )

    # Use Yosys as a priority
    yosys = env.get("FAULT_YOSYS", shutil.which("yosys"))
    if yosys is not None:
        env["FAULT_YOSYS"] = yosys
    elif yowasp_yosys := shutil.which("yowasp-yosys"):
        print(
            f"WARNING: Yosys was not found in either FAULT_YOSYS or PATH, however yowasp-yosys was found as a fallback. This may cause some unexpected behavior.",
            file=sys.stderr,
        )
        env["FAULT_YOSYS"] = yowasp_yosys
    else:
        print(
            f"Warning: Yosys was not found in either FAULT_YOSYS or PATH. The majority of Fault will not work.",
            file=sys.stderr,
        )

    return env


def exec_fault():
    fault_exe = os.path.join(__dir__, "fault.exe")
    os.execle(fault_exe, "fault", *sys.argv[1:], prepare_env())


if __name__ == "__main__":
    exec_fault()
