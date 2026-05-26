from pydantic import BaseModel
from typing import List, Optional

class DistrictHydrationRequest(BaseModel):
    name: str
    region_label: Optional[str] = ""
    focus_area: Optional[str] = "Academic monitoring"

class SchoolHydrationRequest(BaseModel):
    district_name: str
    name: str
    principal: Optional[str] = ""

class ClassHydrationRequest(BaseModel):
    district_name: str
    school_name: str
    name: str
    teacher: Optional[str] = ""

class HydrationResponse(BaseModel):
    success: bool
    detail: Optional[str] = None
