import React, { createContext, useContext, useState } from 'react';
import { useAccount } from 'wagmi';

const WalletContext = createContext();

export const WalletProvider = ({ children }) => {
  const { address, isConnected } = useAccount();
  const [userRole, setUserRole] = useState(null);

  // Método para verificar el rol del usuario desde el contrato
  const checkUserRole = async (contract) => {
    // Aquí iría la lógica para verificar el rol del usuario conectado
  };

  return (
    <WalletContext.Provider value={{ address, isConnected, userRole, setUserRole }}>
      {children}
    </WalletContext.Provider>
  );
};

export const useWallet = () => useContext(WalletContext);
