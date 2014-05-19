#!/usr/bin/python

import re, os

def find_first(cond, l):
	x = filter(cond, l)
	if len(x):
		return x[0]
	else:
		return None

class MezzaninePin:
	def __init__(self, fmc_line=None, port_name=None, io_standard=None):
		self.fmc_line = fmc_line
		self.port_name = port_name
		self.io_standard = io_standard

	def parse(self, s):
		self.fmc_line = s[1]
		self.port_name = s[2]
		self.io_standard= s[3] 

	def __str__(self):
		return "FMC Pin: name %s port %s io %s" % ( self.fmc_line, self.port_name, self.io_standard)

class CarrierPin:
	def __init__(self, fmc_line=None, fmc_slot=None, fpga_pin=None):
		self.fmc_slot = fmc_slot
		self.fmc_line = fmc_line
		self.fpga_pin = fpga_pin

	def parse(self, s):
		self.fmc_slot = int(s[1], 10)
		self.fmc_line = s[2]	
		self.fpga_pin = s[3]	

	def __str__(self):
		return "Carrier Pin: name %s slot %d pin %s" % ( self.fmc_line, self.fmc_slot, self.fpga_pin)

class Carrier:
	def __init__(self, name, num_slots):
		self.name = name
		self.num_slots = num_slots
		self.pins = []
	
	def add_pin(self, pin):
		self.pins.append(pin)

class Mezzanine:
	def __init__(self, name):
		self.name = name
		self.pins = []
	
	def add_pin(self, pin):
		self.pins.append(pin)
		
class UCFGen:
	
	desc_files_path = ["./", "./pin_defs"];
		
	def __init__(self):
		self.carriers = []
		self.mezzanines = []
		pass
	
	def load_desc_file(self, name):
		lines=open(name,"r").read().splitlines()
		print(name)
		import re
		m_ncomments = re.compile("^\s*([^#]+)\s*#?.*$")
		car = mez = None
		for l in lines:
			m=re.match(m_ncomments, l)
			if not m:
				continue
			
			print(m.group(1))
			tokens = m.group(1).split()
			command = tokens[0]
			
			if(command == "carrier"):
				car = Carrier(tokens[1], int(tokens[2], 10))
			elif(command == "mezzanine"):
				mez = Mezzanine(tokens[1])
			elif(command == "pin"):
				if(car):
					p=CarrierPin()
					p.parse(tokens)
					car.add_pin(p)
				elif(mez):
					p=MezzaninePin()
					p.parse(tokens)
					mez.add_pin(p)
				else:
					raise Exception("%s: define a carrier/mezzanine before defining pins." % name)
			else:
				raise Exception("%s: Unrecognized command '%s'." % (name, command))
		if(car):
			self.carriers.append(car)
		elif(mez):
			self.mezzanines.append(mez)

	def load_descs(self):
		for d in self.desc_files_path:
			if not os.path.isdir(d):
				continue
			for f in os.listdir(d):
				fname=d+"/"+f
				if(os.path.isfile(fname) and fname.endswith(".pins")):
					self.load_desc_file(fname)
#		print("Loaded %d carrier and %d mezzanine pin descriptions." % ( len(self.carriers), len(self.mezzanines)))
	
	def dump_descs(self):
		print("Supported carriers:")
		for c in self.carriers:
			print("* %s" % c.name)
		print("Supported mezzanines:")
		for m in self.mezzanines:
			print("* %s" % m.name)


	def generate_ucf(self, ucf_filename, carrier_name, slot_mappings):
		f = None
		try:
			f = open(ucf_filename,"r")
		except:
			pass

		ucf_user=[]
		
		if f:
			ucf_lines=f.read().splitlines()
			usermode = True
			for l in ucf_lines:
				if(l == "# <ucfgen_start>"):
					usermode = False
				if(usermode):
					ucf_user.append(l)
				if (l == "# <ucfgen_end>"):
					usermode = True
			f.close()
			
		car = find_first(lambda car: car.name == carrier_name, self.carriers)
		if not car:
			raise Exception("Unsupported carrier: %s" % carrier_name)

		
		ucf_ours=[]
		ucf_ours.append("")
		ucf_ours.append("# <ucfgen_start>")
		ucf_ours.append("")
		ucf_ours.append("# This section has bee generated automatically by ucfgen.py. Do not hand-modify if not really necessary.")
		
		slot = 0
		for mapping in slot_mappings:
			if not mapping:
				continue
			mez = find_first(lambda mez: mez.name == mapping, self.mezzanines)
			if not mez:
				raise Exception("Unsupported mezzanine: %s " % mapping)
					
			print("Found mezzanine %s for slot %d." % (mez.name, slot))

			if(car.num_slots > 1):
				slot_str = str(slot)
			else:
				slot_str=""

			ucf_ours.append("# ucfgen pin assignments for mezzanine %s slot %d" % (mapping, slot))
			for p in mez.pins:
				p_carrier = find_first(lambda f : f.fmc_line == p.fmc_line and f.fmc_slot == slot, car.pins)
				if (not p_carrier):
					raise Exception("Mezzanine FMC line %s not defined in the carrier description" % p.fmc_line)							
				
				print(p.port_name.replace("%", slot_str))
				
				ucf_ours.append("NET \"%s\" LOC = \"%s\";" % ( p.port_name.replace("%", slot_str), p_carrier.fpga_pin))
				ucf_ours.append("NET \"%s\" IOSTANDARD = \"%s\";" % ( p.port_name.replace("%", slot_str), p.io_standard.upper()))
			slot=slot+1
		ucf_ours.append("# <ucfgen_end>")
		
		f_out = open(ucf_filename, "w")
		for l in ucf_user:
			f_out.write(l+"\n")
		for l in ucf_ours:
			f_out.write(l+"\n")
		f_out.close()	

		print("Successfully updated UCF file %s" % ucf_filename)
							
def usage():
	import getopt, sys
	print("Ucfgen, a trivial script for automatizing Xilinx UCF FMC Mezzanine-Carrier pin assignments.\n")
	print("usage: %s [options] ucf_file" % sys.argv[0])
	print("Options:")
	print(" -h, --help: print this message");
	print(" -c, --carrier <type>: select carrier type");
	print(" -m, --mezzanine <slot:type>: select <type> of mezzanine inserted into carrier slot <slot>");
	print(" -l, --list: list supported carriers and mezzanines");

def main():
	import getopt, sys, os

	if len(sys.argv) == 1:
		print("Missing command line option. Type %s --help for spiritual guidance." % sys.argv[0])
		sys.exit(0)
		
	try:
		opts, args = getopt.getopt(sys.argv[1:], "hlo:m:c:", ["help", "list", "output=", "mezzanine=slot:type", "carrier="])
 	except getopt.GetoptError, err:
		print str(err) 
		usage()
		sys.exit(1)
	
	output = None
	carrier = None
	u = UCFGen()
	u.desc_files_path.append(os.path.dirname(os.path.realpath(sys.argv[0])))
	u.load_descs()
	mezzanines=[]
	for i in range(0,128):
		mezzanines.append(None)
	
	for o, a in opts:
		if o in [ "-h", "--help" ]:
			usage()
			sys.exit()
		elif o in ("-l", "--list"):
			u.dump_descs()
			sys.exit()
		elif o in ("-c", "--carrier"):
		 carrier = a
		elif o in ("-m", "--mezzanine"):
			t=a.split(":")
			mezzanines[int(t[0])] = t[1]
		else:
			assert False, "unhandled option"

	ucf_name = sys.argv[len(sys.argv)-1]

	u.generate_ucf(ucf_name, carrier, mezzanines)
	
main()


#u.generate_ucf("svec_top.ucf", "svec-v0", [ "fmc-delay-v4", "fmc-delay-v4" ])