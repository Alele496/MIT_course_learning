#!/usr/bin/env python3
"""
generate_vmh.py - 生成正确的VMH文件格式
"""

import sys
import os
import subprocess

def main():
    if len(sys.argv) != 3:
        print("用法: python3 generate_vmh.py input.riscv output.vmh")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    print(f"输入文件: {input_file}")
    print(f"输出文件: {output_file}")
    
    # 检查输入文件是否存在
    if not os.path.exists(input_file):
        print(f"错误: 输入文件不存在")
        print(f"请检查路径: {input_file}")
        sys.exit(1)
    
    # 使用绝对路径的objcopy工具
    # OBJCOPY = "/home/sk/Desktop/MIT-tools/risc-v/riscv32-elf-ubuntu-22.04-gcc/riscv/bin/riscv32-unknown-elf-objcopy"
    OBJCOPY = "/usr/local/bin/objcopy"
    
    # 检查objcopy工具是否存在
    if not os.path.exists(OBJCOPY):
        print(f"错误: objcopy工具不存在: {OBJCOPY}")
        sys.exit(1)
    
    print(f"使用objcopy工具: {OBJCOPY}")
    
    # 临时二进制文件
    bin_file = f"{input_file}.bin"
    
    try:
        # 1. 生成二进制文件
        print(f"执行: {OBJCOPY} -O binary {input_file} {bin_file}")
        subprocess.run([OBJCOPY, "-O", "binary", input_file, bin_file], check=True)
        
        # 2. 读取二进制数据
        with open(bin_file, 'rb') as f:
            data = f.read()
        
        print(f"程序大小: {len(data)} 字节")
        
        # 3. 创建64KB内存镜像
        MEM_SIZE = 65536
        OFFSET = 512  # 0x200地址
        
        # 检查程序是否太大
        if OFFSET + len(data) > MEM_SIZE:
            print(f"错误: 程序太大，无法放入内存")
            os.remove(bin_file)
            sys.exit(1)
        
        # 创建内存，初始化为0
        memory = bytearray([0x00] * MEM_SIZE)
        memory[OFFSET:OFFSET + len(data)] = data
        
        # 4. 生成VMH文件
        with open(output_file, 'w') as f:
            f.write('@0\n')
            for i in range(0, MEM_SIZE, 4):
                chunk = memory[i:i+4]
                if len(chunk) < 4:
                    chunk += b'\x00' * (4 - len(chunk))
                # 反转字节顺序（小端转大端）
                f.write(chunk[::-1].hex() + '\n')
        
        print(f"✅ 成功生成VMH文件: {output_file}")
        
        # 显示关键信息
        if len(data) >= 4:
            first_instr = data[0:4]
            print(f"第一条指令: {first_instr[::-1].hex()} (应该是00000013)")
        
        print(f"0x200地址内容: {memory[512:516][::-1].hex()}")
        
    except subprocess.CalledProcessError as e:
        print(f"错误: objcopy执行失败")
        sys.exit(1)
    except Exception as e:
        print(f"错误: {e}")
        sys.exit(1)
    finally:
        # 清理临时文件
        if os.path.exists(bin_file):
            os.remove(bin_file)

if __name__ == "__main__":
    main()
