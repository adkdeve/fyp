
import { useNavigate } from 'react-router-dom';
import { useEffect } from 'react';

const Index = () => {
  const navigate = useNavigate();
  
  // Redirect to homepage
  useEffect(() => {
    navigate('/');
  }, [navigate]);
  
  return null;
};

export default Index;
