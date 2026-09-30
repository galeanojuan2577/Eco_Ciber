import React from 'react';

export const GridBackground = ({ children, className = "" }: { children: React.ReactNode, className?: string }) => {
  return (
    <div className={`relative w-full overflow-hidden bg-white ${className}`}>
      {/* Structural Grid Layer */}
      <div className="absolute inset-0 z-0 opacity-[0.05]" 
           style={{ 
             backgroundImage: `linear-gradient(#64748b 1px, transparent 1px), linear-gradient(90deg, #64748b 1px, transparent 1px)`,
             backgroundSize: '40px 40px' 
           }}>
      </div>
      
      {/* Atmospheric Aurora/Radial Glow Layer */}
      <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-500/10 blur-[120px] rounded-full -mr-64 -mt-64 z-0"></div>
      <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-slate-400/10 blur-[100px] rounded-full -ml-32 -mb-32 z-0"></div>
      
      {/* Content */}
      <div className="relative z-10 w-full">
        {children}
      </div>
    </div>
  );
};

export const DottedBackground = ({ children, className = "" }: { children: React.ReactNode, className?: string }) => {
  return (
    <div className={`relative w-full overflow-hidden bg-[#0F172A] ${className}`}>
      {/* Structural Dot Layer */}
      <div className="absolute inset-0 z-0 opacity-10" 
           style={{ 
             backgroundImage: `radial-gradient(#64748b 0.5px, transparent 0.5px)`,
             backgroundSize: '24px 24px' 
           }}>
      </div>
      
      {/* Atmospheric Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-blue-600/5 blur-[150px] z-0"></div>
      
      {/* Content */}
      <div className="relative z-10 w-full">
        {children}
      </div>
    </div>
  );
};
