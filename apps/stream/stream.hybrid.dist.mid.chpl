use Time;

////////////////////////////////////////////////////////////////////////////////
/// GPUIterator
////////////////////////////////////////////////////////////////////////////////
use GPUIterator;
use GPUAPI;
use BlockDist;
use SysBasic;
use SysCTypes;
use CPtr;

////////////////////////////////////////////////////////////////////////////////
/// Runtime Options
////////////////////////////////////////////////////////////////////////////////
config const n = 32: int;
config const CPUratio = 0: int;
config const numTrials = 1: int;
config const output = 0: int;
config const alpha = 3.0: real(32);
config param verbose = false;

////////////////////////////////////////////////////////////////////////////////
/// Global Arrays
////////////////////////////////////////////////////////////////////////////////
// For now, these arrays are global so the arrays can be seen from CUDAWrapper
// TODO: Explore the possiblity of declaring the arrays and CUDAWrapper
//       in the main proc (e.g., by using lambdas)
var D: domain(1) dmapped Block(boundingBox = {1..n}) = {1..n};
var A: [D] real(32);
var B: [D] real(32);
var C: [D] real(32);

////////////////////////////////////////////////////////////////////////////////
/// C Interoperability
////////////////////////////////////////////////////////////////////////////////
extern proc LaunchStream(A: c_void_ptr, B: c_void_ptr, C: c_void_ptr, alpha: c_float, N: size_t);

// CUDAWrapper is called from GPUIterator
// to invoke a specific CUDA program (using C interoperability)
proc CUDAWrapper(lo: int, hi: int, N: int) {
  if (verbose) {
    var device, count: int(32);
    GetDevice(device);
    GetDeviceCount(count);
    writeln("In CUDAWrapper(), launching the CUDA kernel with a range of ", lo, "..", hi, " (Size: ", N, "), GPU", device, " of ", count, " @", here);
  }

  ref lA = A.localSlice(lo .. hi);
  ref lB = B.localSlice(lo .. hi);
  ref lC = C.localSlice(lo .. hi);
  //writeln("localSlice Size:", lA.size);
  if (verbose) { ProfilerStart(); }
  var dA = new GPUArray(lA);
  var dB = new GPUArray(lB);
  var dC = new GPUArray(lC);

  toDevice(dB, dC);
  LaunchStream(dA.dPtr(), dB.dPtr(), dC.dPtr(), alpha, N: size_t);
  DeviceSynchronize();
  dA.fromDevice();

  if (verbose) { ProfilerStop(); }
}

////////////////////////////////////////////////////////////////////////////////
/// Utility Functions
////////////////////////////////////////////////////////////////////////////////
proc printResults(execTimes) {
  const totalTime = + reduce execTimes,
	avgTime = totalTime / numTrials,
	minTime = min reduce execTimes;
  writeln("Execution time:");
  writeln("  tot = ", totalTime);
  writeln("  avg = ", avgTime);
  writeln("  min = ", minTime);
}

proc printLocaleInfo() {
  for loc in Locales {
    writeln(loc, " info: ");
    const numSublocs = loc.getChildCount();
    if (numSublocs != 0) {
      for sublocID in 0..#numSublocs {
        const subloc = loc.getChild(sublocID);
        writeln("\t Subloc: ", sublocID);
        writeln("\t Name: ", subloc);
        writeln("\t maxTaskPar: ", subloc.maxTaskPar);
      }
    } else {
      writeln("\t Name: ", loc);
      writeln("\t maxTaskPar: ", loc.maxTaskPar);
    }
  }
}

////////////////////////////////////////////////////////////////////////////////
/// Chapel main
////////////////////////////////////////////////////////////////////////////////
proc main() {
  writeln("Stream: CPU/GPU Execution (using GPUIterator)");
  writeln("Size: ", n);
  writeln("CPU ratio: ", CPUratio);
  writeln("nGPUs: ", nGPUs);
  writeln("alpha: ", alpha);
  writeln("nTrials: ", numTrials);
  writeln("output: ", output);

  printLocaleInfo();

  var execTimes: [1..numTrials] real;
  for trial in 1..numTrials {
	forall i in D {
      B(i) = i: real(32);
      C(i) = 2*i: real(32);
	}

	const startTime = getCurrentTime();
	forall i in GPU(D, CUDAWrapper, CPUratio) {
      A(i) = B(i) + alpha * C(i);
	}
	execTimes(trial) = getCurrentTime() - startTime;
	if (output) {
      writeln(A);
      for i in 1..n {
        if(A(i) != B(i) + alpha * C(i)) {
          writeln("Verification Error");
          exit();
        }
      }
      writeln("Verified");
	}
  }
  printResults(execTimes);
}
