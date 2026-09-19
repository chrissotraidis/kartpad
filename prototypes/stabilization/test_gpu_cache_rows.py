#!/usr/bin/env python3
"""Exercise production Dawn cache reads against real SQLite rows, with/without zstd."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=ROOT/'vendor/runtimes/android/aurora-main/lib/webgpu/gpu_cache.cpp')
args = parser.parse_args()
source = args.source.read_text()
loader = source[source.index('size_t load_from_cache('):source.index('\nvoid store_to_cache(')]
preamble = r'''
#include <sqlite3.h>
#include <atomic>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <limits>
#include <mutex>
#include <vector>
#ifdef AURORA_CACHE_USE_ZSTD
#include <zstd.h>
#endif
struct Logger { template<class... T> void error(T...) {} } Log;
namespace sqlite { struct Transaction { Transaction(sqlite3*,Logger&) {} operator bool() const {return true;} }; }
struct XXH128_hash_t { uint64_t low,high; };
XXH128_hash_t XXH128(const void*,size_t,int) {return {1,2};}
std::mutex cache_mutex;
sqlite3* db=nullptr;
sqlite3_stmt* load_stmt=nullptr;
bool cache_init() {return true;}
int check(int result) {assert(result==SQLITE_OK);return result;}
int64_t days_now() {return 100;}
std::atomic<uint64_t> g_lookups=0,g_hits=0,g_hitBytes=0;
std::vector<XXH128_hash_t> g_pendingTouches;
void row(const std::vector<unsigned char>& bytes,int64_t declared,int compressed) {
 check(sqlite3_exec(db,"DELETE FROM cache",nullptr,nullptr,nullptr));
 sqlite3_stmt* insert=nullptr;
 check(sqlite3_prepare_v2(db,"INSERT INTO cache VALUES(?,?,?,?,100)",-1,&insert,nullptr));
 auto key=XXH128(nullptr,0,0);
 check(sqlite3_bind_blob(insert,1,&key,sizeof(key),SQLITE_TRANSIENT));
 check(sqlite3_bind_blob(insert,2,bytes.data(),bytes.size(),SQLITE_TRANSIENT));
 check(sqlite3_bind_int64(insert,3,declared));check(sqlite3_bind_int(insert,4,compressed));
 assert(sqlite3_step(insert)==SQLITE_DONE);check(sqlite3_finalize(insert));
}
'''
main = r'''
int main() {
 check(sqlite3_open(":memory:",&db));
 check(sqlite3_exec(db,"CREATE TABLE cache(key BLOB,value BLOB,size INTEGER,compressed INTEGER,last_used INTEGER)",nullptr,nullptr,nullptr));
 check(sqlite3_prepare_v2(db,"SELECT value,size,compressed,last_used FROM cache WHERE key=?",-1,&load_stmt,nullptr));
 const std::vector<unsigned char> bytes={1,2,3,4};
 auto load=[](void* value=nullptr,size_t size=0){return load_from_cache(nullptr,0,value,size,nullptr);};
 for(int64_t wrong: {-1LL,0LL,3LL,5LL,9223372036854775807LL}) {
  row(bytes,wrong,0);assert(load()==0 && "invalid raw length must be rejected before allocation");
  unsigned char out[8]={};assert(load(out,8)==0);
 }
 row(bytes,bytes.size(),2);assert(load()==0);
 row({},4,0);assert(load()==0);
 row(bytes,bytes.size(),1);assert(load()==0 && "invalid/unsupported compressed row must be a miss");
#ifdef AURORA_CACHE_USE_ZSTD
 std::vector<unsigned char> compressed(ZSTD_compressBound(bytes.size()));
 auto length=ZSTD_compress(compressed.data(),compressed.size(),bytes.data(),bytes.size(),1);
 assert(!ZSTD_isError(length));compressed.resize(length);
 row(compressed,500000000,1);assert(load()==0 && "metadata and zstd frame size must agree before allocation");
 row(compressed,bytes.size(),1);assert(load()==bytes.size());
 unsigned char decoded[4]={};assert(load(decoded,4)==4 && std::memcmp(decoded,bytes.data(),4)==0);
#endif
 // A bad row must not poison the statement or overwrite unrelated cached data.
 row(bytes,bytes.size(),0);assert(load()==4);
 unsigned char out[4]={};assert(load(out,4)==4 && std::memcmp(out,bytes.data(),4)==0);
 sqlite3_stmt* count=nullptr;check(sqlite3_prepare_v2(db,"SELECT count(*) FROM cache",-1,&count,nullptr));
 assert(sqlite3_step(count)==SQLITE_ROW && sqlite3_column_int(count,0)==1);
 check(sqlite3_finalize(count));check(sqlite3_finalize(load_stmt));check(sqlite3_close(db));
}
'''
with tempfile.TemporaryDirectory(prefix='kartpad-cache-rows-') as directory:
    path=Path(directory); (path/'probe.cpp').write_text(preamble+loader+main)
    for zstd in (False,True):
        flags=['-DAURORA_CACHE_USE_ZSTD','-I/opt/homebrew/include','-L/opt/homebrew/lib','-lzstd'] if zstd else []
        subprocess.run(['clang++','-std=c++20','-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer',str(path/'probe.cpp'),'-lsqlite3',*flags,'-o',str(path/'probe')],check=True)
        subprocess.run([str(path/'probe')],check=True,timeout=10)
print('Production cache read tests passed: raw/zstd sizes, malformed rows, valid round trips, statement reuse.')
