#include <dlfcn.h>
#include <cstdio>
int main(int argc, char** argv) {
 if(argc != 2) return 2;
 void* h = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
 if(!h) { puts(dlerror()); return 3; }
 auto run = reinterpret_cast<int(*)()>(dlsym(h, "run_tests"));
 return run ? run() : 4;
}
