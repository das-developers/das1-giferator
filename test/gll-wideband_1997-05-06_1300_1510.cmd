ON_ERROR, 1
RESTORE, giferator.sav
.RUN giferator.pro

batch = 1
display.color.r=interpolate([000,000,000,000,000,255,255,255,255],(findgen(200)+1.)/25.)
display.color.g=interpolate([000,000,255,255,255,255,200,080,000],(findgen(200)+1.)/25.)
display.color.b=interpolate([127,255,255,127,000,000,000,000,000],(findgen(200)+1.)/25.)
display.color.b(0)=1
rows = 2
columns = 2
colormaps = 1
images = 2
axes = 2
labels = 0
sets = 2
device_name = 'Z'
display.isize = 800
display.jsize = 600
colormap_i.klow = 0
colormap_i.khigh = display.color.nz
set_i.ticklen = -0.02
axis_i.set = 0
axis_i.method = 'plot'
init

column(0).ileft = display.isize / 8
column(0).iright = display.isize * 6 / 8
column(0).time = 1
column(0).tleft = '1997 126 13:00'
column(0).tright = '1997 126 15:10'
column(1).ileft = column(0).iright + display.isize / 8
column(1).iright = column(1).ileft + display.isize / 32
row(0).jbottom = display.jsize * 2 / 10
row(0).jtop = display.jsize * 8 / 10
row(0).ybottom = 10
row(0).ytop = 10000
row(1) = row(0)
colormap(0).zlow = 1.e-3
colormap(0).zhigh = 1.e0
colormap(0).log = 1
axis(0).row = 0
axis(0).column = 0
axis(0).timeaxis = 'x'
axis(0).x.title = '1997-05-06 (126) 13:00:00    SCET    1997-05-06 (126) 15:10:00'
axis(0).y.title = 'frequency (Hz)'
axis(0).set = 1
axis(1).row = 1
axis(1).column = 1
axis(1).x.style = supress
axis(1).y.ticklen = -0.2
axis(1).y.title = 'relative power'
image(0).query = ''
image(0).row = 0
image(0).column = 0
image(0).colormap = 0
image(0).dataset = 'gll-wideband_1997-05-06_1300_1510.dsdf'
image(1).row = 1
image(1).column = 1
image(1).colormap = 0
image(1).dataset = 'color_wedge.dsdf'
set(1).title = 'Galileo PWS Wideband'
go

