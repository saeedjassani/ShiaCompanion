"""Turns a rec.js clip (raw frames + timings) into a constant-30fps NNNN.jpg sequence.
Frames are held, not motion-interpolated: ffmpeg's minterpolate ghosts on UI text.
usage: python3 interp.py <clipDir> [--speed 1.0]"""
import glob, json, os, subprocess, sys
import imageio_ffmpeg
d = sys.argv[1]
speed = float(sys.argv[sys.argv.index('--speed') + 1]) if '--speed' in sys.argv else 1.0
for f in glob.glob(os.path.join(d, '[0-9]*.jpg')):
    os.remove(f)
n = round(json.load(open(os.path.join(d, 'taps.json')))['frames'] / speed)
vf = f"setpts=PTS/{speed},tpad=stop_mode=clone:stop_duration=2,fps=30"
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-y', '-f', 'concat', '-safe', '0',
                '-i', os.path.join(d, 'frames.txt'), '-vf', vf, '-frames:v', str(n), '-q:v', '2',
                '-start_number', '0', os.path.join(d, '%04d.jpg')], check=True)
print(os.path.basename(d), n, 'frames')
