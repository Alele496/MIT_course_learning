# Makefile
# 动态库链接
# FFTW_DIR = /home/sk/Desktop/MIT实验环境/Library/6.375lab3-fftw
# CFLAGS = -std=c99 -I$(FFTW_DIR)/include
# LDFLAGS = -L$(FFTW_DIR)/lib -lm -lfftw3

# pitch: pitch.c
# 	gcc $(CFLAGS) pitch.c -o pitch $(LDFLAGS)

pitch: pitch.c
	gcc pitch.c -o pitch libfftw3.a -lm

clean:
	rm -f pitch

run:
	./pitch in.pcm out.pcm

.PHONY: clean run
