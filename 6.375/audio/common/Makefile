
BSC = bsc
BSC_COMPILE_FLAGS = -u -sim -simdir bscdir -bdir bscdir -info-dir bscdir -keep-fires -aggressive-conditions -p +:. -g
BSC_LINK_FLAGS = -sim -simdir bscdir -bdir bscdir -info-dir bscdir -e

# 默认目标
all: mkToMPTest mkFromMPTest

# ToMP测试
mkToMPTest: ToMPTest.bsv ToMP.bsv Cordic.bsv ComplexMP.bsv
	mkdir -p bscdir
	$(BSC) $(BSC_COMPILE_FLAGS) mkToMPTest ToMPTest.bsv
	$(BSC) $(BSC_LINK_FLAGS) mkToMPTest -o mkToMPTest

# FromMP测试
mkFromMPTest: FromMPTest.bsv FromMP.bsv Cordic.bsv ComplexMP.bsv
	mkdir -p bscdir
	$(BSC) $(BSC_COMPILE_FLAGS) mkFromMPTest FromMPTest.bsv
	$(BSC) $(BSC_LINK_FLAGS) mkFromMPTest -o mkFromMPTest

# 运行测试
runToMP: mkToMPTest
	./mkToMPTest

runFromMP: mkFromMPTest
	./mkFromMPTest

# 清理
clean:
	rm -rf bscdir mkToMPTest mkFromMPTest mkToMPTest.so mkToMPTest.so.so mkFromMPTest.so mkFromMPTest.so.so

.PHONY: all mkToMPTest mkFromMPTest runToMP runFromMP runBothTest clean