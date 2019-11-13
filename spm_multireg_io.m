function varargout = spm_multireg_io(varargin)
%__________________________________________________________________________
%
% I/O functions for spm_multireg.
%
% FORMAT to       = spm_multireg_io('CopyFields',from,to)
% FORMAT [P,datn] = spm_multireg_io('GetClasses',datn,mu,sett)
% FORMAT out      = spm_multireg_io('GetData',in)
% FORMAT Mat      = spm_multireg_io('GetMat',fin)
% FORMAT K        = spm_multireg_io('GetK',fn)
% FORMAT [R,datn] = spm_multireg_io('GetResp'datn,fn,mu,adjust,sett)
% FORMAT [d,M]    = spm_multireg_io('GetSize',fin)
% FORMAT is3d     = spm_multireg_io('Is3D',fn)
% FORMAT psi      = spm_multireg_io('ResavePsiSub',datn,sett)
% FORMAT dat      = spm_multireg_io('SaveImages',dat,mu,sett)
% FORMAT fout     = spm_multireg_io('SetData',fin,f)
%
%__________________________________________________________________________
% Copyright (C) 2019 Wellcome Trust Centre for Neuroimaging

if nargin == 0
    help spm_multireg_io
    error('Not enough argument. Type ''help spm_multireg_io'' for help.');
end
id = varargin{1};
varargin = varargin(2:end);
switch id
    case 'CopyFields'
        [varargout{1:nargout}] = CopyFields(varargin{:});                   
    case 'GetClasses'
        [varargout{1:nargout}] = GetClasses(varargin{:});
    case 'GetData'
        [varargout{1:nargout}] = GetData(varargin{:});
    case 'GetK'
        [varargout{1:nargout}] = GetK(varargin{:});            
    case 'GetMat'
        [varargout{1:nargout}] = GetMat(varargin{:});    
    case 'GetResp'
        [varargout{1:nargout}] = GetResp(varargin{:});            
    case 'GetSize'
        [varargout{1:nargout}] = GetSize(varargin{:});
    case 'Is3D'
        [varargout{1:nargout}] = Is3D(varargin{:});        
    case 'ResavePsiSub'
        [varargout{1:nargout}] = ResavePsiSub(varargin{:});    
    case 'SaveImages'
        [varargout{1:nargout}] = SaveImages(varargin{:});    
    case 'SetData'
        [varargout{1:nargout}] = SetData(varargin{:});        
    otherwise
        help spm_multireg_io
        error('Unknown function %s. Type ''help spm_multireg_io'' for help.', id)
end
end
%==========================================================================

%==========================================================================
% CopyFields()
function to = CopyFields(from,to)
fn = fieldnames(from);
for i=1:numel(fn)
    to.(fn{i}) = from.(fn{i});
end
end
%==========================================================================

%==========================================================================
% GetClasses()
function [P,datn] = GetClasses(datn,mu,sett)
if ~isfield(datn,'mog')
    P = GetData(datn.f);

    if nargout > 1
        % Make mask
        msk = sum(P,4) > 0; % Removes voxels that sums to zero across classes..
        msk = msk & sum(~isfinite(P),4) == 0; % ..and voxels that are not finite in segmentation..
        msk = msk & sum(~isfinite(mu),4) == 0; % ..and voxels that are not finite in template

        % Compute subject-specific categorical cross-entropy loss between
        % segmentation and template
        tmp       = sum(P.*mu,4) - spm_multireg_util('lse',mu,4);  
        datn.E(1) = -sum(tmp(msk));
    end
else
    if nargout > 1
        [P,datn] = GetClassesFromGMM(datn,mu,sett);
    else
        P = GetClassesFromGMM(datn,mu,sett);
    end
end

if 0
    % Show stuff
    d  = size(mu);
    d  = [d 1 1];
    K  = d(4);        
    nr = floor(sqrt(K));
    nc = ceil(K/nr);  
        
    for k=1:K    
        % Show template    
        figure(664); subplot(nr,nc,k); imagesc(mu(:,:,ceil(d(3).*0.55),k)'); 
        title('mu');
        axis image xy off; drawnow
        
        % Show segmentation
        figure(665); subplot(nr,nc,k); imagesc(P(:,:,ceil(d(3).*0.55),k)'); 
        title('Seg')
        axis image xy off; drawnow
    end
end
end
%==========================================================================

%==========================================================================
% GetData()
function out = GetData(in)
if isnumeric(in)
    out = single(in);
    return
end
if isa(in,'char')
    in = nifti(in);
end
if isa(in,'nifti')
    M = numel(in);
    d = size(in(1).dat,[1 2 3 4 5]);
    if M>1
        d(4) = M;
        out = zeros(d,'single');
        for m=1:M
            out(:,:,:,m) = single(in(m).dat(:,:,:,:,:));
        end
    else
        out = single(in.dat(:,:,:,:,:));
        if numel(d)>4 && d(4)==1
            out = reshape(out,[d(1:3) d(5)]);
        end
    end
    return
end
error('Unknown datatype.');
end
%==========================================================================

%==========================================================================
% GetK()
function K = GetK(fn)
if iscell(fn(1))
    fn = GetData(fn{1});
else
    fn = GetData(fn(1));
end
K = size(fn,4);
end
%==========================================================================

%==========================================================================
% GetMat()
function Mat = GetMat(fin)
if isnumeric(fin)
    Mat = eye(4);
    return;
end
if isa(fin,'char')
    fin = nifti(fin);
end
if isa(fin,'nifti')
    Mat  = fin(1).mat;
    return
end
error('Unknown datatype.');
end
%==========================================================================

%==========================================================================
% GetResp()
function [R,datn] = GetResp(datn,fn,mu,adjust,sett)
K   = size(mu,2);
mog = datn.mog;
R   = zeros([numel(fn),K+1],'single');
for k=1:(K+1)
    R(:,k) = -((fn - mog.mu(k)).^2)/(2*mog.sig2(k)+eps) - 0.5*log(2*pi*mog.sig2(k)+eps);
    if k<=K, R(:,k) = R(:,k) + mu(:,k); end
end
pmx = max(R,[],2);
R   = R - pmx;
R   = exp(R);
sR  = sum(R,2);

% Negative log-likelihood
if isempty(adjust)
    maxmu  = max(max(mu,[],2),0);
    adjust = sum(log(sum(exp(mu-maxmu),2) + exp(-maxmu))+maxmu);
end
datn.E(1) = -sum(log(sR) + pmx,1) + adjust; % doesn't account for priors (so can increase)
%fprintf(' %g\n', datn.E(1));

R = R./sR;
end
%==========================================================================

%==========================================================================
% GetSize()
function [d,M] = GetSize(fin)
d = [GetDimensions(fin) 1 1 1];
M = d(4);
d = d(1:3);
end
%==========================================================================

%==========================================================================
% Is3D()
function is3d = Is3D(fn)
if iscell(fn(1))
    fn = GetData(fn{1});
else
    fn = GetData(fn(1));
end
d    = GetSize(fn);
is3d = d(3) > 1;
end
%==========================================================================

%==========================================================================
% ResavePsiSub()
function psi = ResavePsiSub(datn,sett)
d    = GetSize(datn.f);
q    = double(datn.q);
Mn   = datn.Mat;
psi1 = GetData(datn.psi);
psi  = spm_multireg_util('Compose',psi1,spm_multireg_util('Affine',d,sett.var.Mmu\spm_dexpm(q,sett.registr.B)*Mn));
psi  = reshape(reshape(psi,[prod(d) 3])*sett.var.Mmu(1:3,1:3)' + sett.var.Mmu(1:3,4)',[d 1 3]);
if isa(datn.psi(1),'nifti')
    to_delete = datn.psi(1).dat.fname;
    [~,nam,~] = fileparts(datn.f(1).dat.fname);
    datn.psi(1).dat.fname = fullfile(sett.write.dir_res,['y_' nam '.nii']);
    datn.psi(1).dat.dim = [d 1 3];
    datn.psi(1).mat = datn.f(1).mat0; % For working with "imported" images;
   %datn.psi(1).mat = Mn;
    datn.psi(1).descrip = 'Deformation';
    create(datn.psi(1));
    datn.psi(1).dat(:,:,:,:,:) = psi;
    delete(to_delete);
end
end
%==========================================================================

%==========================================================================
% SaveImages()
function dat = SaveImages(dat,mu,sett)
for n=1:numel(dat)
    dat(n).psi = ResavePsiSub(dat(n),sett);
end

if ~isempty(mu)
    % Save mu (log)
    fa       = file_array(fullfile(sett.write.dir_res ,'mu_log.nii'),size(mu),'float32',0);
    Nmu      = nifti;
    Nmu.dat  = fa;
    Nmu.mat  = sett.var.Mmu;
    Nmu.mat0 = sett.var.Mmu;
    Nmu.descrip = 'Mean parameters (log)';
    create(Nmu);
    Nmu.dat(:,:,:,:) = mu;
    
    % Save mu (softmax)    
    mu       = spm_multireg_util('softmaxmu',mu,4);    
    fa       = file_array(fullfile(sett.write.dir_res ,'mu_softmax.nii'),size(mu),'float32',0);
    Nmu      = nifti;
    Nmu.dat  = fa;
    Nmu.mat  = sett.var.Mmu;
    Nmu.mat0 = sett.var.Mmu;
    Nmu.descrip = 'Mean parameters (softmax)';
    create(Nmu);
    Nmu.dat(:,:,:,:) = mu;
end
end
%==========================================================================

%==========================================================================
% SetData()
function fout = SetData(fin,f)
fout = fin;
if isnumeric(fin)
    fout = f;
    return
end
if isa(fin,'char')
    fin = nifti(fin);
end
if isa(fin,'nifti')
    M    = numel(fin);
    if M>1
        for m=1:M
            fout(m).dat(:,:,:,1,:) = f(:,:,:,m,:);
        end
    else
        fout(1).dat(:,:,:,:,:) = reshape(f,size(fout(1).dat));
    end
    return
end
end
%==========================================================================

%==========================================================================
%
% Utility functions
%
%==========================================================================

%==========================================================================
% comp_resp()
function R = comp_resp(fn,mu,code,datn)

% Is there missing data?
L       = unique(code);
do_miss = numel(unique(code)) > 1;

% Posterior
m = datn.mog.po.m;
b = datn.mog.po.b;
V = datn.mog.po.V;
n = datn.mog.po.n;

if do_miss, const = spm_gmm_lib('Const', {m,b}, {V,n}, L);
else,       const = spm_gmm_lib('Const', {m,b}, {V,n});
end

fn = spm_gmm_lib('Marginal', fn, {m,V,n}, const, {code,L});
R  = spm_gmm_lib('Responsibility', fn, mu);
end
%==========================================================================

%==========================================================================
% GetClassesFromGMM()
function [R,datn] = GetClassesFromGMM(datn,mu,sett)
fn = GetData(datn.f);
d0 = GetDimensions(datn.f);
C  = d0(4);
K  = size(mu,4);
K1 = K + 1;
fn = reshape(fn,[prod(d0(1:3)) C]);

% Missing data stuff
fn      = mask(fn);
code    = spm_gmm_lib('obs2code', fn);
L       = unique(code);
do_miss = numel(unique(code)) > 1;

% Posterior
m  = datn.mog.po.m;
b  = datn.mog.po.b;
V  = datn.mog.po.V;
n  = datn.mog.po.n;

% Prior
m0 = datn.mog.pr.m;
b0 = datn.mog.pr.b;
V0 = datn.mog.pr.V;
n0 = datn.mog.pr.n;

% Make softmaxed K + 1 template
mu = log(spm_multireg_util('softmaxmu',mu,4));
mu = reshape(mu,[prod(d0(1:3)) K1]);

if nargout > 1    
    % Update GMM and get responsibilities
               
    if sett.gen.samp_gmm > 1
        % Subsample (runs faster)        
        code0    = code;
        code     = reshape(code,[d0(1:3) 1]);
        [code,d] = spm_multireg_util('SubSample',code,datn.Mat,sett.gen.samp_gmm);       
        code     = reshape(code,[prod(d(1:3)) 1]);
        fn0      = fn;
        fn       = reshape(fn,[d0(1:3) C]);
        [fn,d]   = spm_multireg_util('SubSample',fn,datn.Mat,sett.gen.samp_gmm);       
        fn       = reshape(fn,[prod(d(1:3)) C]);
        mu0      = mu;
        mu       = reshape(mu,[d0(1:3) K1]);
        [mu,d]   = spm_multireg_util('SubSample',mu,datn.Mat,sett.gen.samp_gmm);       
        mu       = reshape(mu,[prod(d(1:3)) K1]);                
    end        
       
    [R,mog,~,lb] = spm_gmm_loop(fn,{{m,b},{V,n}},{'LogProp', mu}, ...
                                'GaussPrior',   {m0,b0,V0,n0}, ...
                                'Missing',      do_miss, ...
                                'MissingCode',  {code,L}, ...
                                'IterMax',      sett.nit.gmm, ...
                                'Tolerance',    1e-4, ...
                                'SubIterMax',   sett.nit.gmm_miss, ...
                                'SubTolerance', 1e-4, ...
                                'Verbose',      0);
    clear mu code
    
    % Update datn
    datn.mog.po.m = mog.MU; % GMM posteriors
    datn.mog.po.b = mog.b;
    datn.mog.po.V = mog.V;
    datn.mog.po.n = mog.n;    
    datn.E(1)     = -sum(lb.sum(end)); % objective function
    
    if sett.gen.samp_gmm > 1
        % Compute responsibilities on original data         
        R = comp_resp(fn0,mu0,code0,datn);
    end    
else
    % Just compute responsibilities    
    R = comp_resp(fn,mu,code,datn);
end

% Get 4D versions
R = reshape(R(:,1:K),[d0(1:3) K]);
end
%==========================================================================

%==========================================================================
% mask()
function fn = mask(fn)
C = size(fn,2);
for c=1:C
    fn(:,c) = spm_multireg_util('Mask',fn(:,c));
end
end
%==========================================================================