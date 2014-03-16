#!gnumake
LD      = /usr/local/opt/gcc46/bin/g++-4.6
FLAGS   = -O2 -Wall -fPIC 
INCLUDE = -I . -I$(RUBYINC)
#
all: lib_dir ../lib/$(OS_NAME)/cppvector.bundle ../lib/$(OS_NAME)/dataset.bundle ../lib/$(OS_NAME)/dcs.bundle ../lib/$(OS_NAME)/evt.bundle ../lib/$(OS_NAME)/norm_int.bundle
#
lib_dir:; 
	@mkdir -p ../lib/$(OS_NAME)

#
objects/%.o: %.cpp
	$(LD) $(FLAGS) $(INCLUDE) -c -o objects/$*.o $*.cpp
#
../lib/$(OS_NAME)/%.bundle: objects/%.o
	$(LD) -dynamic -bundle objects/$*.o -o ../lib/$(OS_NAME)/$*.bundle -L$(RUBYLIB) -lruby -ldl -lm -lc
	@chmod 555 ../lib/$(OS_NAME)/$*.bundle
#
%.o: %.cpp
	$(LD) $(FLAGS) $(INCLUDE) -c -o $*.o $*.cpp
#
%.bundle: %.o
	$(LD) -shared $*.o -o -L$(RUBYLIB) -ldl -lm -lc -lruby -ldl -lobjc $*.bundle
	@chmod 555 $*.bundle
#
clean:;
	@rm -f objects/*.o ../lib/$(OS_NAME)/*.bundle
