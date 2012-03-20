function df = dF4ienv(R,dataParameter)

[r u]=size(R);

sigRes=dataParameter.sigRes;
sigY=dataParameter.sigY;
sigFit=sigY-sigRes;
p=dataParameter.p;

    
    temp=inv(sigRes);
    a=2*sigRes*R*inv(R'*sigRes*R)+2*temp*R*inv(R'*temp*R);
    
    R0=grams(nulbasis(R'));
    temp1=inv(R0'*sigRes*R0);
    temp2=R0'*sigFit*R0;
    dzdg0=kron(eye(r-u),temp1*R0'*sigFit)+Kpd(kron(temp1,R0'*sigFit),r-u,r-u)-kron(temp2*temp1,temp1*R0'*sigRes)-Kpd(kron(temp1,temp2*temp1*R0'*sigRes),r-u,r-u);
    dg0dg1=-Kpd_right(kron(R0',R),r,u);
    
    [V0 D0]=eig(temp1);
    MultiPlier=V0*diag(sqrt(diag(D0)))*V0';
    [Vtmp Dtmp]=eig(MultiPlier*temp2*MultiPlier);
    [Ds ind]=sort(diag(Dtmp),'descend');
    b=zeros(1,(r-u)^2);

    
    for i=(p-u+1):(r-u)
        V=inv(MultiPlier)*Vtmp(:,i);
        U=MultiPlier*Vtmp(:,i);
        b=b+1/(1+Ds(i))*reshape(V*U',1,(r-u)^2);
    end
    
    b=b*dzdg0*dg0dg1;
    
    df=a+reshape(b,r,u);
