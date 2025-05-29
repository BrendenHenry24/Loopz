// Fast Fourier Transform implementation
export class FFT {
  private size: number;
  private cosTable: Float32Array;
  private sinTable: Float32Array;
  private window: Float32Array;

  constructor(size: number) {
    this.size = size;
    
    // Precompute tables
    this.cosTable = new Float32Array(size);
    this.sinTable = new Float32Array(size);
    
    for (let i = 0; i < size; i++) {
      const angle = (2 * Math.PI * i) / size;
      this.cosTable[i] = Math.cos(angle);
      this.sinTable[i] = Math.sin(angle);
    }
    
    // Create Hanning window
    this.window = new Float32Array(size);
    for (let i = 0; i < size; i++) {
      this.window[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (size - 1)));
    }
  }

  forward(input: Float32Array): Float32Array {
    const size = this.size;
    const output = new Float32Array(size);
    
    // Apply window function
    for (let i = 0; i < size; i++) {
      output[i] = input[i] * this.window[i];
    }
    
    // Bit reversal
    for (let i = 0; i < size; i++) {
      const j = this.reverseBits(i, Math.log2(size));
      if (j > i) {
        const temp = output[i];
        output[i] = output[j];
        output[j] = temp;
      }
    }
    
    // FFT computation
    for (let step = 2; step <= size; step *= 2) {
      const halfStep = step / 2;
      
      for (let group = 0; group < size; group += step) {
        for (let pair = 0; pair < halfStep; pair++) {
          const twiddle = pair * (size / step);
          const cos = this.cosTable[twiddle];
          const sin = this.sinTable[twiddle];
          
          const groupStart = group + pair;
          const matchStart = group + pair + halfStep;
          const match = output[matchStart];
          
          const real = cos * match;
          const imag = sin * match;
          
          output[matchStart] = output[groupStart] - real;
          output[groupStart] = output[groupStart] + real;
        }
      }
    }
    
    return output;
  }

  private reverseBits(num: number, bits: number): number {
    let result = 0;
    for (let i = 0; i < bits; i++) {
      result = (result << 1) | (num & 1);
      num >>= 1;
    }
    return result;
  }
}