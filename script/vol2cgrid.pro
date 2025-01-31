pro vol2cgrid,niifiles,cgridfiles,flag=flag,enc=enc
syntx=n_params()
if syntx lt 2 then begin
print,'Usage:'
print,'The nifi files to convert'
print,'The cgridfile'
print,'Set keyword enc to use enclosing voxel algorithm. Default is trilinear'
print,'Set keyword flag to use different mapping options of mri_vol2surf'
return
end
if not keyword_set(flag) then flag='--projfrac 0.5'
flag=' '+flag
spawn,'echo $SUBJECTS_DIR',fsdir
hems=['lh','rh']
subcode=replace(replace(file_dirname(cgridfiles(0)),fsdir+'/',''),'/surf','')
patchcode=replace(replace(replace(file_basename(cgridfiles(0)),'.cgrid',''),'lh_',''),'rh_','')
surfdir=fsdir+'/'+subcode+'/surf/'
regfile=surfdir+'register_'+trim(randomu(a,/long))+'.dat'
nrniifiles=n_elements(niifiles)
nrcgridfiles=n_elements(cgridfiles)
tmpcgriddat=read_ascii(cgridfiles(0))
tmpcgriddat=tmpcgriddat.(0)
xdim=ceil(max(tmpcgriddat(1,*)))
ydim=ceil(max(tmpcgriddat(2,*)))
cgrids=create_struct(patchcode+'_'+trim(1),tmpcgriddat)
if nrcgridfiles gt 1 then for i=1,nrcgridfiles-1 do begin
tmpcgriddat=read_ascii(cgridfiles(i))
tmpcgriddat=tmpcgriddat.(0)
tmpxdim=ceil(max(tmpcgriddat(1,*)))
tmpydim=ceil(max(tmpcgriddat(2,*)))
if tmpxdim gt xdim then xdim=tmpxdim
if tmpydim gt ydim then ydim=tmpydim
cgrids=create_struct(cgrids,patchcode+'_'+trim(i+1),tmpcgriddat)
end
mvals=fltarr(xdim,ydim,2)+1
if keyword_set(enc) then begin
for j=0,nrcgridfiles-1 do begin 
hem=strmid(file_basename(cgridfiles(j)),0,2)
sind=where(hems eq hem)
cgrid=cgrids.(j)
for k=0,xdim-1 do for l=0,ydim-1 do if where(floor(cgrid(1,*)) eq k and floor(cgrid(2,*)) eq l,/NULL) eq !NULL then mvals(k,l,sind)=0
end
end
areas=create_struct('lh',read_fs_surfdat(surfdir+'lh.area.mid'))
areas=create_struct(areas,'rh',read_fs_surfdat(surfdir+'rh.area.mid'))
for i=0,nrniifiles-1 do begin
spawn,'tkregister2 --mov '+niifiles(i)+' --s '+subcode+' --regheader --noedit --reg '+regfile
for j=0,nrcgridfiles-1 do begin
hem=strmid(file_basename(cgridfiles(j)),0,2)
sind=where(hems eq hem)
area=areas.(sind)
cgrid=cgrids.(j)
if not keyword_set(enc) then begin
;topo=(read_fs_surface(surfdir+hem+'.pial')).topology
;topotest=bytarr(max(topo)+1)
;topotest(cgrid(0,*))=1
;tinc=bytarr(3,n_elements(topo)/3)
;for k=0,2 do tinc(k,*)=topotest(topo(k,*))
;topo=topo(*,where(total(tinc,1) eq 3))
;atopo=topo*0
;for k=0,n_elements(cgrid(0,*))-1 do atopo(where(topo eq cgrid(0,k)))=k+1
;atopo=atopo(*,where(min(atopo,dimension=1) ne 0,/NULL))-1
triangulate,cgrid(1,*),cgrid(2,*),atopo
mval=trigrid(cgrid(1,*),cgrid(2,*),intarr(n_elements(cgrid(0,*)))+1,atopo,nx=xdim+2,ny=ydim+2)
mvals(*,*,sind)=round(mval(1:xdim,1:ydim))
end
print,'Start mapping '+niifiles(i)+' to '+hem+' surface'
spawn,'mri_vol2surf --src '+niifiles(i)+' --srcreg '+regfile+' --hemi '+hem+' --out '+surfdir+hem+'_'+patchcode+'_tmp.mgh'+flag
print,'Done'
readmgh,surfdir+hem+'_'+patchcode+'_tmp.mgh',surfdat
spawn,'rm '+surfdir+hem+'_'+patchcode+'_tmp.mgh'
nrscans=n_elements(surfdat(0,0,0,*))
surfdat=reform(surfdat,n_elements(surfdat(*,0,0,0)),nrscans)
if j eq 0 then opdat=fltarr(xdim,ydim,2,nrscans)
if keyword_set(enc) then begin
for k=0,nrscans-1 do surfdat(*,k)=surfdat(*,k)*area
for k=0,xdim-1 do for l=0,ydim-1 do begin
inc=where(floor(cgrid(1,*)) eq k and floor(cgrid(2,*)) eq l,/NULL)
if inc ne !NULL then opdat(k,l,sind,*)=total(surfdat(cgrid(0,inc),*),1)/total(area((cgrid(0,inc))))
end
end
if not keyword_set(enc) then for k=0,nrscans-1 do begin
tmpdat=trigrid(cgrid(1,*),cgrid(2,*),surfdat(cgrid(0,*),k),atopo,nx=xdim+2,ny=ydim+2)
opdat(*,*,sind,k)=tmpdat(1:xdim,1:ydim)
end
end
for l=0,1 do begin
tmpinc=where(mvals(*,*,l) eq 0,/NULL)
if tmpinc ne !NULL then for k=0,nrscans-1 do begin
tmpdat=opdat(*,*,l,k)
tmpdat(tmpinc)=!VALUES.F_NAN
smtmpdat=gauss_smooth(tmpdat,0.5,/NAN,/edge_truncate,/normalize)
tmpdat(tmpinc)=smtmpdat(tmpinc)
opdat(*,*,l,k)=tmpdat
end
end
spawn,'rm '+regfile
outputfile=file_basename(niifiles(i))
dtest=strpos(outputfile,'-')
if dtest ne -1 then outputfile=strmid(outputfile,0,dtest)+'_cgrid_'+patchcode+strmid(outputfile,dtest,strlen(outputfile)) else outputfile=replace(outputfile,'.nii','')+'_cgrid_'+patchcode+'.nii'
wrfile=file_dirname(niifiles(i))+'/'+outputfile
print,'Writing '+wrfile
niihdrtool,wrfile,fdata=opdat,srow_x4=-xdim/2.+0.5,srow_y4=-ydim/2.+0.5,srow_z4=-0.5
print,'Done'
end
end
