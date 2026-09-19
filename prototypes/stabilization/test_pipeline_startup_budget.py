#!/usr/bin/env python3
"""Execute production cache admission and worker scheduling with SQLite/fake compiler jobs."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'vendor/runtimes/android/aurora-main/lib/gfx/pipeline_cache.cpp').read_text()
loader = source[source.index('template <typename PipelineConfig, typename CreateFn>\nstatic void load_pipeline_cache_entries'):source.index('\nstatic void load_pipeline_cache()')]
worker = source[source.index('static void pipeline_worker()'):source.index('\nstatic void build_synchronous_pipelines_for_frame()')]
promotion = source[source.index('template <typename Queue>\nstatic auto find_pending_pipeline'):source.index('// A persistent resolve')]
constants = '\n'.join(line for line in source.splitlines() if line.startswith('constexpr size_t Max') and any(n in line for n in ['MaxPipelineWorkers', 'MaxBackgroundPipelineWorkers', 'MaxPrewarmPipelineBuilds']))
preamble = r'''
#include <sqlite3.h>
#include <algorithm>
#include <atomic>
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <deque>
#include <future>
#include <mutex>
#include <thread>
#include <type_traits>
#include <vector>
using PipelineRef = uint64_t;
using HashType = uint64_t;
enum class ShaderType { Clear, GX };
int underlying(ShaderType t) { return static_cast<int>(t); }
struct Config { uint32_t version=1, id=0; };
namespace gx { using PipelineConfig = Config; bool valid_pipeline_config(const Config& c) { return c.id != 999999; } }
struct Logger { template<class... T> void error(T...) {} template<class... T> void warn(T...) {} } Log;
sqlite3* db=nullptr;
sqlite3*& g_pipelineCacheDb=db;
sqlite3_stmt* g_pipelineCacheLoadStmt=nullptr;
bool aborted=false;
bool prepare_pipeline_cache_db() { return true; }
void pipeline_cache_abort() { aborted=true; }
uint64_t xxh3_hash_s(const uint8_t* data, size_t size, HashType type) {
 uint64_t hash=type;for(size_t i=0;i<size;++i)hash=hash*33+data[i];return hash;
}
std::vector<unsigned> loaded;
template<class C,class F> void find_pipeline_impl(ShaderType,const C& c,F&&,bool,unsigned) { loaded.push_back(c.id); }
struct PendingPipeline { PipelineRef hash; };
std::mutex g_pipelineMutex;
std::condition_variable g_pipelineCv;
std::deque<PendingPipeline> g_priorityPipelines,g_backgroundPipelines;
size_t g_activeBackgroundPipelineWorkers=0;
bool g_pipelineThreadEnd=false;
std::atomic<int> backgroundEntered=0,priorityEntered=0;
std::mutex compileMutex;
std::condition_variable compileCv;
bool releaseBackground=false;
void compile_pending_pipeline(PendingPipeline p) {
 if(p.hash==10000) { ++priorityEntered;compileCv.notify_all();return; }
 ++backgroundEntered;compileCv.notify_all();
 std::unique_lock l(compileMutex);compileCv.wait(l,[]{return releaseBackground;});
}
'''
main = r'''
int main() {
 assert(sqlite3_open(":memory:",&db)==SQLITE_OK);
 assert(sqlite3_exec(db,"CREATE TABLE recipes(type INTEGER,hash INTEGER,config BLOB,frame INTEGER,version INTEGER);",nullptr,nullptr,nullptr)==SQLITE_OK);
 sqlite3_stmt* insert=nullptr;
 assert(sqlite3_prepare_v2(db,"INSERT INTO recipes VALUES(?,?,?,?,1)",-1,&insert,nullptr)==SQLITE_OK);
 for(unsigned i=0;i<3587;++i) {
  Config c{1,i};auto type=i<3?ShaderType::Clear:ShaderType::GX;
  sqlite3_bind_int(insert,1,static_cast<int>(type));
  sqlite3_bind_int64(insert,2,xxh3_hash_s(reinterpret_cast<const uint8_t*>(&c),sizeof(c),static_cast<HashType>(type)));
  sqlite3_bind_blob(insert,3,&c,sizeof(c),SQLITE_TRANSIENT);sqlite3_bind_int(insert,4,i);
  assert(sqlite3_step(insert)==SQLITE_DONE);sqlite3_reset(insert);
 }
 sqlite3_finalize(insert);
 assert(sqlite3_prepare_v2(db,"SELECT hash,config,frame FROM recipes WHERE type=? AND version=? ORDER BY frame",-1,&g_pipelineCacheLoadStmt,nullptr)==SQLITE_OK);
 size_t remaining=MaxPrewarmPipelineBuilds;
 load_pipeline_cache_entries<Config>(ShaderType::Clear,1,[](auto){},remaining);
 load_pipeline_cache_entries<Config>(ShaderType::GX,1,[](auto){},remaining);
 assert(!aborted && loaded.size()==128 && remaining==0);
 assert(loaded.front()==0 && loaded.back()==127);
 // Exhaustion is not a SQLite error and the statement remains reusable.
 load_pipeline_cache_entries<Config>(ShaderType::GX,1,[](auto){},remaining);
 assert(!aborted && loaded.size()==128);
 sqlite3_stmt* count=nullptr;sqlite3_prepare_v2(db,"SELECT count(*) FROM recipes",-1,&count,nullptr);
 assert(sqlite3_step(count)==SQLITE_ROW && sqlite3_column_int(count,0)==3587);sqlite3_finalize(count);
 // Rows not prewarmed remain available on demand, without deleting any cache state.
 remaining=4000;loaded.clear();load_pipeline_cache_entries<Config>(ShaderType::GX,1,[](auto){},remaining);
 assert(!aborted && loaded.size()==3584 && loaded.back()==3586);
 sqlite3_finalize(g_pipelineCacheLoadStmt);sqlite3_close(db);
 // One blocked speculative compile must not occupy all six workers or block demand work.
 for(unsigned i=0;i<128;++i)g_backgroundPipelines.push_back({i});
 std::vector<std::thread> threads;for(int i=0;i<6;++i)threads.emplace_back(pipeline_worker);
 {std::unique_lock l(compileMutex);assert(compileCv.wait_for(l,std::chrono::seconds(2),[]{return backgroundEntered.load()>0;}));}
 {std::lock_guard l(g_pipelineMutex);g_backgroundPipelines.push_back({10000});assert(touch_pending_pipeline(10000,true)!=nullptr);}
 {std::unique_lock l(compileMutex);assert(compileCv.wait_for(l,std::chrono::seconds(2),[]{return priorityEntered.load()==1;}));}
 assert(backgroundEntered==1);
 {std::lock_guard l(g_pipelineMutex);g_pipelineThreadEnd=true;}g_pipelineCv.notify_all();
 {std::lock_guard l(compileMutex);releaseBackground=true;}compileCv.notify_all();
 for(auto& thread:threads)thread.join();
 assert(g_activeBackgroundPipelineWorkers==0);
}
'''
with tempfile.TemporaryDirectory(prefix='kartpad-pipeline-budget-') as d:
    p=Path(d); (p/'probe.cpp').write_text(preamble+'\n'+constants+'\n'+loader+'\n'+promotion+'\n'+worker+'\n'+main)
    subprocess.run(['clang++','-std=c++20','-O1','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer','-pthread',str(p/'probe.cpp'),'-lsqlite3','-o',str(p/'probe')],check=True)
    subprocess.run([str(p/'probe')],check=True,timeout=10)
print('Production cache admission/SQLite reuse/cache preservation and priority-worker progress passed.')
