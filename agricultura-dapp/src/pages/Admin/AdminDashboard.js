import React from 'react';
import { Box, Button } from '@chakra-ui/react';
import { useAccount } from 'wagmi';
import { ethers } from 'ethers';
import AssetManagerABI from '../../abis/AssetManager.json'; // ABI del contrato AssetManager

const AdminDashboard = () => {
  const { address, isConnected } = useAccount();

  // Ejemplo de función para conectar y verificar el rol de administrador
  const checkAdminRole = async () => {
    if (!isConnected) {
      alert("Por favor, conecta tu wallet primero");
      return;
    }

    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const contract = new ethers.Contract(
        'DIRECCIÓN_DEL_CONTRATO_ASSETMANAGER',
        AssetManagerABI,
        provider
      );

      const hasAdminRole = await contract.hasRole(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DEFAULT_ADMIN_ROLE")),
        address
      );

      if (hasAdminRole) {
        alert("Eres administrador");
      } else {
        alert("No tienes permisos de administrador");
      }
    } catch (error) {
      console.error("Error verificando el rol de administrador", error);
    }
  };

  return (
    <Box>
      <Button onClick={checkAdminRole}>Verificar Rol de Administrador</Button>
      {/* Agregar más funcionalidades de administración aquí */}
    </Box>
  );
};

export default AdminDashboard;
