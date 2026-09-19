#include "batch_reservation.hpp"
#include <cassert>
#include <iostream>
#include <random>
using namespace kartpad::prototype;
int main() {
  std::vector<Range> ranges;
  BatchReservation b({32, 512+3840, 16, 256}, {0,3840,0,0});
  const std::array draw{Request{Buffer::Vertex,16,0},Request{Buffer::Uniform,16,256},
                        Request{Buffer::Index,8,0},Request{Buffer::Storage,16,256}};
  assert(b.reserve(draw,ranges)==Admission::Accepted);
  auto old=b.used(); auto oldRanges=ranges;
  // Vertex/uniform/index fit, storage does not: no partial commit.
  assert(b.reserve(draw,ranges)==Admission::Flush);assert(b.used()==old);
  assert(ranges.size()==oldRanges.size() && ranges[0].offset==oldRanges[0].offset);
  b.reset_after_submission();assert(b.reserve(draw,ranges)==Admission::Accepted);
  const std::array oversized{Request{Buffer::Vertex,33,0}};
  old=b.used();assert(b.reserve(oversized,ranges)==Admission::Oversized);assert(b.used()==old);
  const std::array overflow{Request{Buffer::Uniform,UINT64_MAX,256}};
  assert(b.reserve(overflow,ranges)==Admission::Invalid);assert(b.used()==old);
  BatchReservation zero({4,256+3840,4,256}, {0,3840,0,0});
  const std::array zeros{Request{Buffer::Uniform,0,256},Request{Buffer::Storage,0,256}};
  assert(zero.reserve(zeros,ranges)==Admission::Accepted);assert(zero.used()[1]==256);
  assert(zero.reserve(zeros,ranges)==Admission::Flush);
  BatchReservation copyTail({5,4,4,4}, {});
  const std::array unaligned{Request{Buffer::Vertex,5,0}};
  assert(copyTail.reserve(unaligned,ranges)==Admission::Oversized);
  BatchReservation uniform({4,24*1024*1024,4,4}, {0,3840,0,0});
  const std::array interpolated{Request{Buffer::Uniform,3840,256},Request{Buffer::Uniform,3840,256},
                                Request{Buffer::Uniform,3840,256},Request{Buffer::Uniform,3840,256}};
  unsigned accepted=0;
  while(uniform.reserve(interpolated,ranges)==Admission::Accepted) ++accepted;
  assert(accepted==((24*1024*1024-3840)/(3840*4)));
  BatchReservation helpers({0,512+3840,0,0},{0,3840,0,0});
  const std::array clearAndResolve{Request{Buffer::Uniform,16,256},Request{Buffer::Uniform,48,256}};
  assert(helpers.reserve(clearAndResolve,ranges)==Admission::Accepted);
  old=helpers.used();
  const std::array nativeReadback{Request{Buffer::Uniform,48,256}};
  assert(helpers.reserve(nativeReadback,ranges)==Admission::Flush);assert(helpers.used()==old);
  helpers.reset_after_submission();assert(helpers.reserve(nativeReadback,ranges)==Admission::Accepted);
  // Copy padding consumes the final uint32_t-addressable bytes; another small
  // request needs a new batch rather than being classified as intrinsically large.
  BatchReservation addressLimit({UINT32_MAX,0,0,0},{});
  const std::array almostFull{Request{Buffer::Vertex,UINT32_MAX-3,0}};
  const std::array another{Request{Buffer::Vertex,8,0}};
  assert(addressLimit.reserve(almostFull,ranges)==Admission::Accepted);
  assert(addressLimit.reserve(another,ranges)==Admission::Flush);
  // Randomized independent byte-budget oracle; failed reservations retain all cursors.
  std::mt19937 random(0x4b415254);
  for(unsigned trial=0;trial<1000;++trial) {
    Sizes caps{1024,4096,512,2048}, used{};
    BatchReservation batch(caps,{0,384,0,0});
    for(unsigned step=0;step<100;++step) {
      std::array<Request,4> requests;
      Sizes next=used, empty{};
      for(unsigned i=0;i<4;++i) {
        uint64_t n=random()%400;
        requests[i]={Buffer(i),n,4};
        uint64_t rounded=n?((n+3)/4)*4:4;
        next[i]+=rounded;empty[i]=rounded;
      }
      bool fits=true, alone=true;
      for(unsigned i=0;i<4;++i) {auto tail=i==1?384u:0u;fits &= next[i]+tail<=caps[i];alone &= empty[i]+tail<=caps[i];}
      const auto result=batch.reserve(requests,ranges);
      assert(result==(!alone?Admission::Oversized:fits?Admission::Accepted:Admission::Flush));
      if(fits && alone) used=next;
      assert(batch.used()==used);
      if(result==Admission::Flush) {batch.reset_after_submission();used={};}
    }
  }
  std::cout << "PASS: atomic admission, padding, interpolation budget, overflow, oversized draws; 100000 randomized reservations\n";
}
