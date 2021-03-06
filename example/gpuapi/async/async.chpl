use GPUAPI;
use SysCTypes;
use CPtr;
use Futures;

extern proc kernel(dA: c_void_ptr);

var D = {0..127};
var A: [D] int;
var V: [D] int; // for Verification
for i in D {
    A(i) = i;
}
V = A + 1;

var F = async(lambda () {
        writeln("GPU Ctrl Thread");
        var dA = new GPUArray(A);
        dA.toDevice();
        kernel(dA.dPtr());
        dA.fromDevice();
        return 1;
    });

writeln("CPU Task here");
if (F.get() == 1) {
    writeln("GPU done");
    if (A.equals(V)) {
        writeln("Verified");
    } else {
        writeln("Not Verified");
    }
}

