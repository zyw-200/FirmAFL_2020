import os
import sys

def generate_run_firmafl(image_id, arch):
	script_src = "firmadyne/scratch/%s/run.sh" %image_id
	script_dst = "firmadyne/scratch/%s/run_firmafl.sh" %image_id
	file_src = open(script_src)
	file_dst = open(script_dst, "w+")
	for line in file_src.readlines():
		if "sleep 1s" in line:
			file_dst.write(line)
			archh = arch
			if cmp(arch, "mipseb") == 0:
				archh = "mips"
			elif cmp(arch, "armel") == 0:
				archh = "arm"
			newline_0 = "QEMU=./qemu-system-%s\n" %archh
			if cmp(archh, "mipsel") == 0 or cmp(archh, "mips") == 0:
				newline_1 = "KERNEL='./vmlinux.%s_3.2.1'\n" %archh
			elif cmp(archh, "arm") == 0:
				newline_1 = "KERNEL='./zImage.armel'\n"
			newline_2 = "IMAGE='./image.raw'\n"
			newline_3 = "MEM_FILE='./mem_file'\n"
			file_dst.write(newline_0)
			file_dst.write(newline_1)
			file_dst.write(newline_2)
			file_dst.write(newline_3)
		elif "${QEMU_MACHINE}" in line:
			new_line = "${QEMU} -m 256 -mem-prealloc -mem-path ${MEM_FILE} -M ${QEMU_MACHINE} -kernel ${KERNEL} \\\n"
			#new_line = "${QEMU} -m 256  -M ${QEMU_MACHINE} -kernel ${KERNEL} \\\n"
			file_dst.write(new_line)
		elif "tee" in line:
			new_line = line.split("|")[0] + "\\\n"
			file_dst.write(new_line)
		else:
			file_dst.write(line)
	file_src.close()
	file_dst.close()
	chmod_str = "chmod 777 %s" %script_dst
	os.system(chmod_str)


#single

image_id = sys.argv[1]	
arch = sys.argv[2]
generate_run_firmafl(image_id, arch)

'''
fp = open("testlist")
for line in fp.readlines():
	array = line.split(":")
	image_id = array[0].strip()
	generate_run_full(image_id)
fp.close()
'''